import Foundation

enum InstallStatus: Equatable {
    case unknown
    case installed(configs: [OrgConfig])
    case notInstalled
}

enum ProfileDetector {
    static let managedPath = "/Library/Managed Preferences/com.cloudflare.warp.plist"

    static func managedFileModifiedAt() -> Date? {
        let attrs = try? FileManager.default.attributesOfItem(atPath: managedPath)
        return attrs?[.modificationDate] as? Date
    }

    static func detect() -> InstallStatus {
        if let configs = readManagedConfigs() {
            return .installed(configs: configs)
        }
        if profilesListContainsWarp() {
            return .installed(configs: [])
        }
        return .notInstalled
    }

    private static func readManagedConfigs() -> [OrgConfig]? {
        let url = URL(fileURLWithPath: managedPath)
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { return nil }
        guard let raw = plist["configs"] as? [[String: Any]] else { return [] }
        return raw.compactMap { dict in
            guard let org = dict["organization"] as? String,
                  let name = dict["display_name"] as? String else { return nil }
            return OrgConfig(displayName: name, organization: org)
        }
    }

    private static func profilesListContainsWarp() -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/profiles")
        task.arguments = ["list", "-type", "configuration"]
        let out = Pipe()
        task.standardOutput = out
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
        } catch { return false }
        let s = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return s.localizedCaseInsensitiveContains("cloudflare_warp")
    }
}
