import SwiftUI
import AppKit

@main
struct WarpConfiguratorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = ConfigStore()

    var body: some Scene {
        WindowGroup("Cloudflare WARP Configurator") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 760, minHeight: 480)
        }
        .windowResizability(.contentSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
