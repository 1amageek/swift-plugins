import Foundation

/// Generates provider-specific compatibility files from canonical package files.
public struct PluginMaterializer: Sendable {
    public enum Provider: Sendable, Hashable {
        case claude
    }

    private let jsonEncoder: JSONEncoder

    public init(jsonEncoder: JSONEncoder = JSONEncoder()) {
        self.jsonEncoder = jsonEncoder
        self.jsonEncoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    }

    public func materializeCompatibilityFiles(for plugin: Plugin, provider: Provider, at packageURL: URL) throws {
        switch provider {
        case .claude:
            try materializeClaudeFiles(for: plugin, at: packageURL)
        }
    }

    private func materializeClaudeFiles(for plugin: Plugin, at packageURL: URL) throws {
        try writeJSON(plugin.manifest, to: PluginParser.legacyManifestURL(in: packageURL))
        if let mcpConfiguration = plugin.mcpConfiguration {
            try writeJSON(mcpConfiguration, to: PluginParser.legacyMCPConfigurationURL(in: packageURL))
        }
    }

    private func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        do {
            try jsonEncoder.encode(value).write(to: url)
        } catch {
            throw PluginWriterError.fileWriteFailed(url, error.localizedDescription)
        }
    }
}
