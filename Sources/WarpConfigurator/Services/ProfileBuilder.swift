import Foundation

enum ProfileBuilderError: LocalizedError {
    case missingGuid
    case emptyConfigs
    case incompleteOrg

    var errorDescription: String? {
        switch self {
        case .missingGuid: return String(localized: "Profile has no GUID assigned.", bundle: .module)
        case .emptyConfigs: return String(localized: "Add at least one organisation.", bundle: .module)
        case .incompleteOrg: return String(localized: "Fill in both the name and the prefix for each organisation.", bundle: .module)
        }
    }
}

struct ProfileBuilder {
    func build(_ profile: WarpProfile) throws -> Data {
        guard !profile.payloadGuid.isEmpty, !profile.wrapperGuid.isEmpty else {
            throw ProfileBuilderError.missingGuid
        }
        guard !profile.configs.isEmpty else { throw ProfileBuilderError.emptyConfigs }

        let innerConfigs: [[String: Any]] = try profile.configs.map { cfg in
            let org = cfg.organization.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = cfg.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !org.isEmpty, !name.isEmpty else { throw ProfileBuilderError.incompleteOrg }
            return ["organization": org, "display_name": name]
        }

        let inner: [String: Any] = [
            "PayloadDisplayName": "Warp Configuration",
            "PayloadIdentifier": "com.cloudflare.warp.\(profile.payloadGuid)",
            "PayloadOrganization": "Cloudflare Ltd.",
            "PayloadType": "com.cloudflare.warp",
            "PayloadUUID": profile.payloadGuid,
            "PayloadVersion": 1,
            "configs": innerConfigs
        ]

        let outer: [String: Any] = [
            "PayloadContent": [inner],
            "PayloadDisplayName": "Cloudflare WARP",
            "PayloadIdentifier": "cloudflare_warp",
            "PayloadOrganization": "Cloudflare, Ltd.",
            "PayloadRemovalDisallowed": false,
            "PayloadScope": "System",
            "PayloadType": "Configuration",
            "PayloadUUID": profile.wrapperGuid,
            "PayloadVersion": 1
        ]

        return try PropertyListSerialization.data(
            fromPropertyList: outer,
            format: .xml,
            options: 0
        )
    }
}
