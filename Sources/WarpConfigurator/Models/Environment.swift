import Foundation

struct OrgConfig: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var displayName: String
    var organization: String

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case organization
    }
}

struct WarpProfile: Codable, Equatable {
    var payloadGuid: String
    var wrapperGuid: String
    var configs: [OrgConfig]
}
