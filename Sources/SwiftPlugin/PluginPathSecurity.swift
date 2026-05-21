import Foundation

/// Filesystem containment checks for plugin package paths.
enum PluginPathSecurity {
    static func validateRelativePath(_ relativePath: String) -> Bool {
        guard !relativePath.isEmpty else { return false }
        guard !relativePath.hasPrefix("/") else { return false }
        guard !relativePath.hasPrefix("~") else { return false }
        guard !relativePath.contains("\\") else { return false }

        let components = relativePath.split(separator: "/", omittingEmptySubsequences: false)
        guard !components.isEmpty else { return false }
        return components.allSatisfy { component in
            component != "." && component != ".." && !component.isEmpty
        }
    }

    static func containedURL(root: URL, relativePath: String) throws -> URL {
        guard validateRelativePath(relativePath) else {
            throw PluginWriterError.unsafePath(relativePath)
        }

        let rootURL = root.standardizedFileURL
        let fileURL = rootURL.appending(path: relativePath).standardizedFileURL
        guard contains(fileURL, in: rootURL) else {
            throw PluginWriterError.unsafePath(relativePath)
        }
        return fileURL
    }

    static func relativePath(for fileURL: URL, in rootURL: URL) throws -> String {
        let rootPath = rootURL.standardizedFileURL.path(percentEncoded: false)
        let filePath = fileURL.standardizedFileURL.path(percentEncoded: false)
        let prefix = rootPath.hasSuffix("/") ? rootPath : "\(rootPath)/"
        guard filePath.hasPrefix(prefix) else {
            throw PluginParserError.unsafePath(filePath)
        }

        var relativePath = String(filePath.dropFirst(prefix.count))
        while relativePath.hasSuffix("/") {
            relativePath.removeLast()
        }
        guard validateRelativePath(relativePath) else {
            throw PluginParserError.unsafePath(relativePath)
        }
        return relativePath
    }

    static func rejectSymbolicLink(_ url: URL) throws {
        let values = try url.resourceValues(forKeys: [.isSymbolicLinkKey])
        if values.isSymbolicLink == true {
            throw PluginParserError.symbolicLinkUnsupported(url)
        }
    }

    static func rejectExistingSymbolicLinkComponents(fileURL: URL, rootURL: URL) throws {
        let fm = FileManager.default
        let rootPath = rootURL.standardizedFileURL.path(percentEncoded: false)
        let filePath = fileURL.standardizedFileURL.path(percentEncoded: false)
        let prefix = rootPath.hasSuffix("/") ? rootPath : "\(rootPath)/"
        guard filePath.hasPrefix(prefix) else {
            throw PluginWriterError.unsafePath(filePath)
        }

        let relativePath = String(filePath.dropFirst(prefix.count))
        var currentURL = rootURL.standardizedFileURL
        for component in relativePath.split(separator: "/", omittingEmptySubsequences: false) {
            currentURL = currentURL.appending(path: String(component))
            let path = currentURL.path(percentEncoded: false)
            if fm.fileExists(atPath: path), isSymbolicLink(path: path) {
                throw PluginWriterError.symbolicLinkUnsupported(currentURL)
            }
        }
    }

    private static func contains(_ fileURL: URL, in rootURL: URL) -> Bool {
        let rootPath = rootURL.path(percentEncoded: false)
        let filePath = fileURL.path(percentEncoded: false)
        return filePath == rootPath || filePath.hasPrefix(rootPath.hasSuffix("/") ? rootPath : "\(rootPath)/")
    }

    private static func isSymbolicLink(path: String) -> Bool {
        do {
            _ = try FileManager.default.destinationOfSymbolicLink(atPath: path)
            return true
        } catch {
            return false
        }
    }
}
