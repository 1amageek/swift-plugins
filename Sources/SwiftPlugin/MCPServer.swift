import Foundation

/// A single MCP server entry.
public struct MCPServer: Sendable, Hashable, Codable {
    public var type: MCPTransport
    public var command: String?
    public var args: [String]?
    public var url: String?
    public var environment: [String: String]
    public var runtimeRef: String?

    public init(
        type: MCPTransport,
        command: String? = nil,
        args: [String]? = nil,
        url: String? = nil,
        environment: [String: String] = [:],
        runtimeRef: String? = nil
    ) {
        self.type = type
        self.command = command
        self.args = args
        self.url = url
        self.environment = environment
        self.runtimeRef = runtimeRef
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case command
        case args
        case url
        case environment = "env"
        case runtimeRef
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(MCPTransport.self, forKey: .type)
        command = try container.decodeIfPresent(String.self, forKey: .command)
        args = try container.decodeIfPresent([String].self, forKey: .args)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        environment = try container.decodeIfPresent([String: String].self, forKey: .environment) ?? [:]
        runtimeRef = try container.decodeIfPresent(String.self, forKey: .runtimeRef)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(command, forKey: .command)
        try container.encodeIfPresent(args, forKey: .args)
        try container.encodeIfPresent(url, forKey: .url)
        if !environment.isEmpty {
            try container.encode(environment, forKey: .environment)
        }
        try container.encodeIfPresent(runtimeRef, forKey: .runtimeRef)
    }
}
