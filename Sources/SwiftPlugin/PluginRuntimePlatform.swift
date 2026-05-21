import Foundation

public struct PluginRuntimePlatform: Sendable, Hashable, Codable {
    public var os: String
    public var arch: String?

    public init(os: String, arch: String? = nil) {
        self.os = os
        self.arch = arch
    }
}
