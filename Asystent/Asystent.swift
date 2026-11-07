import Foundation
import AVFoundation
import Speech

/// Najprostszy możliwy klient: trzyma sesję audio w tle, pyta serwer o kolejkę i wypowiada teksty po polsku;
/// dyktowanie (pl-PL) wysyła na serwer, odpowiedź też czyta głosem.
@MainActor final class Asystent: ObservableObject {
    static let wspolny = Asystent()
    static let serwer = "http://100.64.23.4:8835"   // Tailscale; adres pochodzi z /etc/jadro/adresy.env po stronie serwera
    @Published var log: [String] = ["Start"]
    @Published var slucha = false
    private let synt = AVSpeechSynthesizer()
    private let silnik = AVAudioEngine()
    private var rozp: SFSpeechAudioBufferRecognitionRequest?
    private var zadanie: SFSpeechRecognitionTask?
    private var ostatni = 0
    private var petla: Task<Void, Never>?

    func start() {
        guard petla == nil else { return }
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playAndRecord, mode: .spokenAudio, options: [.duckOthers, .defaultToSpeaker, .allowBluetoothA2DP])
        try? s.setActive(true)
        SFSpeechRecognizer.requestAuthorization { _ in }
        petla = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.zapytaj()
            }
        }
    }

    private func zapytaj() async {
        guard let url = URL(string: Self.serwer + "/kolejka?po=\(ostatni)") else { return }
        var rq = URLRequest(url: url); rq.timeoutInterval = 40
        do {
            let (d, _) = try await URLSession.shared.data(for: rq)
            let arr = (try? JSONSerialization.jsonObject(with: d) as? [[String: Any]]) ?? []
            for e in arr { ostatni = max(ostatni, e["nr"] as? Int ?? 0); powiedz(e["tekst"] as? String ?? "") }
        } catch { dopisz("brak połączenia: \(error.localizedDescription)"); try? await Task.sleep(nanoseconds: 5_000_000_000) }
    }

    func powiedz(_ t: String) {
        guard !t.isEmpty else { return }
        dopisz("mówię: \(t)")
        let u = AVSpeechUtterance(string: t)
        u.voice = AVSpeechSynthesisVoice(language: "pl-PL")
        synt.speak(u)
    }

    func czytajZadania() {
        Task { if let u = URL(string: Self.serwer + "/czytaj"), let (d, _) = try? await URLSession.shared.data(from: u) {
            powiedz(String(decoding: d, as: UTF8.self)) } }
    }

    func dyktuj() {
        if slucha { return koniec(wyslij: true) }
        guard let r = SFSpeechRecognizer(locale: Locale(identifier: "pl-PL")), r.isAvailable else { return dopisz("brak rozpoznawania mowy") }
        let req = SFSpeechAudioBufferRecognitionRequest(); rozp = req
        let wej = silnik.inputNode
        wej.removeTap(onBus: 0)
        wej.installTap(onBus: 0, bufferSize: 1024, format: wej.outputFormat(forBus: 0)) { b, _ in req.append(b) }
        silnik.prepare(); try? silnik.start(); slucha = true; dopisz("słucham…")
        var tekst = ""
        zadanie = r.recognitionTask(with: req) { [weak self] wynik, blad in
            if let w = wynik { tekst = w.bestTranscription.formattedString
                if w.isFinal { Task { @MainActor in self?.wyslij(tekst) } } }
            if blad != nil { Task { @MainActor in self?.koniec(wyslij: false) } }
        }
    }

    private func koniec(wyslij: Bool) {
        silnik.stop(); silnik.inputNode.removeTap(onBus: 0); rozp?.endAudio(); slucha = false
    }

    private func wyslij(_ tekst: String) {
        koniec(wyslij: false)
        guard !tekst.isEmpty, let url = URL(string: Self.serwer + "/powiedz") else { return }
        dopisz("wysyłam: \(tekst)")
        var rq = URLRequest(url: url); rq.httpMethod = "POST"
        rq.httpBody = try? JSONSerialization.data(withJSONObject: ["tekst": tekst, "agent": "max"])
        Task { if let (d, _) = try? await URLSession.shared.data(for: rq) { powiedz(String(decoding: d, as: UTF8.self)) } }
    }

    private func dopisz(_ s: String) { log.append(s); log = Array(log.suffix(30)) }
}
