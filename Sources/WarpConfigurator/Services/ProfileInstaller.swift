import Foundation
import AppKit

enum ProfileInstaller {
    @discardableResult
    static func install(data: Data, displayName: String) throws -> URL {
        let safe = displayName
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safe).mobileconfig")
        try data.write(to: url, options: .atomic)
        NSWorkspace.shared.open(url)
        return url
    }

    /// Opent System Settings → Profielen rechtstreeks.
    static func openProfilesPane() {
        let candidates = [
            "x-apple.systempreferences:com.apple.Profiles-Settings.extension",
            "x-apple.systempreferences:com.apple.settings.Profiles",
            "x-apple.systempreferences:com.apple.preferences.configurationprofiles"
        ]
        for c in candidates {
            if let url = URL(string: c) {
                NSWorkspace.shared.open(url)
                return
            }
        }
    }
}
