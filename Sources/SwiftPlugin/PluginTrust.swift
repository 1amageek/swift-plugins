import Foundation

/// Trust metadata stored in package-root `trust.json`.
public struct PluginTrust: Sendable, Hashable, Codable {
    public var digests: [String: String]
    public var signature: String?
    public var provenance: String?

    public init(
        digests: [String: String] = [:],
        signature: String? = nil,
        provenance: String? = nil
    ) {
        self.digests = digests
        self.signature = signature
        self.provenance = provenance
    }
}
