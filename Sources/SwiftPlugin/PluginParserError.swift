import Foundation

public enum PluginParserError: Error, Sendable, LocalizedError {
    case pluginDirectoryNotFound(URL)
    case missingManifest(URL)
    case invalidManifest(URL, String)
    case invalidMCPConfiguration(URL, String)
    case invalidTrust(URL, String)
    case unsafePath(String)
    case symbolicLinkUnsupported(URL)

    public var errorDescription: String? {
        switch self {
        case .pluginDirectoryNotFound(let url):
            "Plugin directory was not found at \(url.path(percentEncoded: false))."
        case .missingManifest(let url):
            "Plugin manifest was not found at \(url.path(percentEncoded: false))."
        case .invalidManifest(let url, let reason):
            "Plugin manifest at \(url.path(percentEncoded: false)) is invalid: \(reason)."
        case .invalidMCPConfiguration(let url, let reason):
            "MCP configuration at \(url.path(percentEncoded: false)) is invalid: \(reason)."
        case .invalidTrust(let url, let reason):
            "Plugin trust metadata at \(url.path(percentEncoded: false)) is invalid: \(reason)."
        case .unsafePath(let path):
            "Plugin path is unsafe: \(path)."
        case .symbolicLinkUnsupported(let url):
            "Plugin packages must not contain symbolic links: \(url.path(percentEncoded: false))."
        }
    }
}
