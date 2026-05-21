import Foundation

public enum PluginWriterError: Error, Sendable, LocalizedError {
    case directoryCreationFailed(URL)
    case fileWriteFailed(URL, String)
    case unsafePath(String)
    case symbolicLinkUnsupported(URL)

    public var errorDescription: String? {
        switch self {
        case .directoryCreationFailed(let url):
            "Could not create directory at \(url.path(percentEncoded: false))."
        case .fileWriteFailed(let url, let reason):
            "Could not write file at \(url.path(percentEncoded: false)): \(reason)."
        case .unsafePath(let path):
            "Could not write unsafe relative path: \(path)."
        case .symbolicLinkUnsupported(let url):
            "Refusing to write through symbolic link: \(url.path(percentEncoded: false))."
        }
    }
}
