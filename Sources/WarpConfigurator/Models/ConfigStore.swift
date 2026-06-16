import Foundation
import Combine

@MainActor
final class ConfigStore: ObservableObject {
    @Published var profile: WarpProfile {
        didSet { if profile != oldValue { save() } }
    }

    let fileURL: URL

    init() {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/warpconf", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("profile.json")

        if let data = try? Data(contentsOf: fileURL),
           let loaded = try? JSONDecoder().decode(WarpProfile.self, from: data) {
            profile = WarpProfile(
                payloadGuid: loaded.payloadGuid.isEmpty ? UUID().uuidString.uppercased() : loaded.payloadGuid,
                wrapperGuid: loaded.wrapperGuid.isEmpty ? UUID().uuidString.uppercased() : loaded.wrapperGuid,
                configs: loaded.configs
            )
        } else {
            profile = WarpProfile(
                payloadGuid: UUID().uuidString.uppercased(),
                wrapperGuid: UUID().uuidString.uppercased(),
                configs: []
            )
        }

        if profile.configs.isEmpty, case .installed(let detected) = ProfileDetector.detect(), !detected.isEmpty {
            profile.configs = detected
        }
        save()
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(profile) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    func addOrg() {
        profile.configs.append(OrgConfig(displayName: "", organization: ""))
    }

    func remove(id: UUID) {
        profile.configs.removeAll { $0.id == id }
    }

    func importDetected() {
        if case .installed(let cfgs) = ProfileDetector.detect(), !cfgs.isEmpty {
            profile.configs = cfgs
        }
    }
}
