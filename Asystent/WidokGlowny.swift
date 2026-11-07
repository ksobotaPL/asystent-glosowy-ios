import SwiftUI

struct WidokGlowny: View {
    @StateObject private var a = Asystent.wspolny
    var body: some View {
        VStack(spacing: 16) {
            Button(a.slucha ? "Skończ i wyślij" : "Dyktuj") { a.dyktuj() }.buttonStyle(.borderedProminent).font(.title)
            Button("Czytaj moje zadania") { a.czytajZadania() }.buttonStyle(.bordered)
            Button("Test głosu") { a.powiedz("Test asystenta. Mówię po polsku prosto z serwera.") }.buttonStyle(.bordered)
            List(a.log.reversed(), id: \.self) { Text($0).font(.footnote) }
        }.padding().onAppear { a.start() }
    }
}
