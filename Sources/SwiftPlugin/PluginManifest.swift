import Foundation

/// Metadata stored in package-root `plugin.json`.
public struct PluginManifest: Sendable, Hashable, Codable {
    public var schemaVersion: String
    public var id: String
    public var name: String
    public var displayName: String?
    public var version: String?
    public var description: String?
    public var author: PluginAuthor?
    public var homepageURL: String?
    public var license: String?
    public var capabilities: [PluginCapability]
    public var runtimes: [PluginRuntime]
    public var permissions: PluginPermissions?
    public var compatibility: PluginCompatibility?
    public var metadata: [String: String]

    public init(
        schemaVersion: String = "1",
        id: String,
        name: String,
        displayName: String? = nil,
        version: String? = nil,
        description: String? = nil,
        author: PluginAuthor? = nil,
        homepageURL: String? = nil,
        license: String? = nil,
        capabilities: [PluginCapability] = [],
        runtimes: [PluginRuntime] = [],
        permissions: PluginPermissions? = nil,
        compatibility: PluginCompatibility? = nil,
        metadata: [String: String] = [:]
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.name = name
        self.displayName = displayName
        self.version = version
        self.description = description
        self.author = author
        self.homepageURL = homepageURL
        self.license = license
        self.capabilities = capabilities
        self.runtimes = runtimes
        self.permissions = permissions
        self.compatibility = compatibility
        self.metadata = metadata
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case id
        case name
        case displayName
        case displayNameSnake = "display_name"
        case version
        case description
        case author
        case homepageURL
        case homepageURLSnake = "homepage_url"
        case license
        case capabilities
        case runtime
        case runtimes
        case permissions
        case compatibility
        case metadata
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(String.self, forKey: .schemaVersion) ?? "1"
        name = try container.decode(String.self, forKey: .name)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? name
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
            ?? container.decodeIfPresent(String.self, forKey: .displayNameSnake)
        version = try container.decodeIfPresent(String.self, forKey: .version)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        author = try container.decodeIfPresent(PluginAuthor.self, forKey: .author)
        homepageURL = try container.decodeIfPresent(String.self, forKey: .homepageURL)
            ?? container.decodeIfPresent(String.self, forKey: .homepageURLSnake)
        license = try container.decodeIfPresent(String.self, forKey: .license)
        capabilities = try container.decodeIfPresent([PluginCapability].self, forKey: .capabilities) ?? []
        if let runtime = try container.decodeIfPresent(PluginRuntime.self, forKey: .runtime) {
            runtimes = [runtime]
        } else {
            runtimes = try container.decodeIfPresent([PluginRuntime].self, forKey: .runtimes) ?? []
        }
        permissions = try container.decodeIfPresent(PluginPermissions.self, forKey: .permissions)
        compatibility = try container.decodeIfPresent(PluginCompatibility.self, forKey: .compatibility)
        metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata) ?? [:]
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(displayName, forKey: .displayName)
        try container.encodeIfPresent(version, forKey: .version)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(author, forKey: .author)
        try container.encodeIfPresent(homepageURL, forKey: .homepageURL)
        try container.encodeIfPresent(license, forKey: .license)
        if !capabilities.isEmpty {
            try container.encode(capabilities, forKey: .capabilities)
        }
        if !runtimes.isEmpty {
            try container.encode(runtimes, forKey: .runtimes)
        }
        try container.encodeIfPresent(permissions, forKey: .permissions)
        try container.encodeIfPresent(compatibility, forKey: .compatibility)
        if !metadata.isEmpty {
            try container.encode(metadata, forKey: .metadata)
        }
    }
}
