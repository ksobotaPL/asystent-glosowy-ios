import SwiftUI
import AppIntents

@main struct AsystentApp: App {
    var body: some Scene { WindowGroup { WidokGlowny() } }
}

// Action Button / Siri / Skróty: "Asystent — dyktuj" otwiera aplikację i od razu słucha.
struct Dyktuj: AppIntent {
    static var title: LocalizedStringResource = "Asystent — dyktuj"
    static var openAppWhenRun = true
    @MainActor func perform() async throws -> some IntentResult { Asystent.wspolny.dyktuj(); return .result() }
}
struct Skroty: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: Dyktuj(), phrases: ["Dyktuj w \(.applicationName)"], shortTitle: "Dyktuj", systemImageName: "mic")
    }
}
