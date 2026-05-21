import Foundation

/// Permission metadata requested by a plugin package.
public struct PluginPermissions: Sendable, Hashable, Codable {
    public var network: [String]
    public var filesystem: [String]
    public var process: [String]
    public var environment: [String]

    public init(
        network: [String] = [],
        filesystem: [String] = [],
        process: [String] = [],
        environment: [String] = []
    ) {
        self.network = network
        self.filesystem = filesystem
        self.process = process
        self.environment = environment
    }
}
