import Foundation

/// Capability kinds declared by `plugin.json`.
public enum PluginCapability: String, Sendable, Hashable, Codable {
    case skill
    case mcp
    case runtime
    case resource
}
