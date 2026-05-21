import Foundation

/// Runtime requirement and launch declaration for MCP-backed plugins.
public struct PluginRuntime: Sendable, Hashable, Codable {
    public var id: String
    public var kind: PluginRuntimeKind
    public var entrypoint: String?
    public var args: [String]
    public var requiredVersion: String?
    public var platforms: [PluginRuntimePlatform]
    public var environment: [String: String]
    public var workingDirectory: String?

    public init(
        id: String,
        kind: PluginRuntimeKind,
        entrypoint: String? = nil,
        args: [String] = [],
        requiredVersion: String? = nil,
        platforms: [PluginRuntimePlatform] = [],
        environment: [String: String] = [:],
        workingDirectory: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.entrypoint = entrypoint
        self.args = args
        self.requiredVersion = requiredVersion
        self.platforms = platforms
        self.environment = environment
        self.workingDirectory = workingDirectory
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case kind
        case entrypoint
        case args
        case requiredVersion
        case platforms
        case environment
        case workingDirectory
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        kind = try container.decode(PluginRuntimeKind.self, forKey: .kind)
        entrypoint = try container.decodeIfPresent(String.self, forKey: .entrypoint)
        args = try container.decodeIfPresent([String].self, forKey: .args) ?? []
        requiredVersion = try container.decodeIfPresent(String.self, forKey: .requiredVersion)
        platforms = try container.decodeIfPresent([PluginRuntimePlatform].self, forKey: .platforms) ?? []
        environment = try container.decodeIfPresent([String: String].self, forKey: .environment) ?? [:]
        workingDirectory = try container.decodeIfPresent(String.self, forKey: .workingDirectory)
    }
}
