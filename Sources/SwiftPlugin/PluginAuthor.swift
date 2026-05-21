import Foundation

/// Author metadata declared by `plugin.json`.
public struct PluginAuthor: Sendable, Hashable, Codable {
    public var name: String
    public var url: String?

    public init(name: String, url: String? = nil) {
        self.name = name
        self.url = url
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case url
    }

    public init(from decoder: Decoder) throws {
        let singleValue = try decoder.singleValueContainer()
        do {
            let name = try singleValue.decode(String.self)
            self.name = name
            self.url = nil
            return
        } catch {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            url = try container.decodeIfPresent(String.self, forKey: .url)
        }
    }
}
