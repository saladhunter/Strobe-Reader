import SwiftUI
import AppKit

@main
struct SpeedReaderApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView() // Your existing ContentView
        }
        .commands {
            // Replace the default "About" menu item
            CommandGroup(replacing: .appInfo) {
                Button("About SpeedReader") {
                    showAboutPanel()
                }
            }
        }
    }

    func showAboutPanel() {
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "SpeedReader"
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let credits = Bundle.main.object(forInfoDictionaryKey: "CFBundleGetInfoString") as? String ?? "SpeedReader"

        let options: [NSApplication.AboutPanelOptionKey: Any] = [
            .applicationName: appName,
            .applicationVersion: version,
            .credits: credits
        ]

        NSApplication.shared.orderFrontStandardAboutPanel(options: options)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
