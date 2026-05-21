import Foundation

/// Host and platform compatibility metadata declared by a plugin package.
public struct PluginCompatibility: Sendable, Hashable, Codable {
    public var minimumAuroraVersion: String?
    public var platforms: [PluginRuntimePlatform]

    public init(
        minimumAuroraVersion: String? = nil,
        platforms: [PluginRuntimePlatform] = []
    ) {
        self.minimumAuroraVersion = minimumAuroraVersion
        self.platforms = platforms
    }
}
