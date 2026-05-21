import Foundation

/// Configuration stored in package-root `mcp.json`.
public struct MCPConfiguration: Sendable, Hashable, Codable {
    public var servers: [String: MCPServer]

    public init(servers: [String: MCPServer] = [:]) {
        self.servers = servers
    }

    private enum CodingKeys: String, CodingKey {
        case servers = "mcpServers"
    }
}
