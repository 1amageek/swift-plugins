import Foundation

public enum MCPTransport: String, Sendable, Hashable, Codable {
    case stdio
    case http
    case streamableHTTP = "streamable_http"
}
