import Foundation

public enum PluginRuntimeKind: String, Sendable, Hashable, Codable {
    case none
    case externalHTTP
    case node
    case binary
}
