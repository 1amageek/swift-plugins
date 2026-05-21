import Foundation

/// Filesystem-backed plugin storage.
public struct PluginStore: Sendable {
    public let rootURL: URL

    private let parser: PluginParser
    private let writer: PluginWriter

    public init(
        rootURL: URL,
        parser: PluginParser = PluginParser(),
        writer: PluginWriter = PluginWriter()
    ) {
        self.rootURL = rootURL
        self.parser = parser
        self.writer = writer
    }

    public func discover() throws -> [Plugin] {
        let fm = FileManager.default
        let rootPath = rootURL.path(percentEncoded: false)
        guard fm.fileExists(atPath: rootPath) else { return [] }

        return try fm.contentsOfDirectory(atPath: rootPath)
            .sorted()
            .compactMap { name -> Plugin? in
                if name.hasPrefix(".") || !name.hasSuffix(".\(PluginPackage.pathExtension)") { return nil }
                let pluginURL = rootURL.appending(path: name, directoryHint: .isDirectory)
                guard fm.fileExists(atPath: PluginParser.manifestURL(in: pluginURL).path(percentEncoded: false)) else {
                    return nil
                }
                return try parser.parse(at: pluginURL)
            }
    }

    public func plugin(named name: String) throws -> Plugin? {
        let url = url(forPluginNamed: name)
        guard FileManager.default.fileExists(atPath: PluginParser.manifestURL(in: url).path(percentEncoded: false)) else {
            return nil
        }
        return try parser.parse(at: url)
    }

    public func save(_ plugin: Plugin) throws {
        try writer.write(plugin, to: url(forPluginNamed: plugin.manifest.name))
    }

    public func delete(named name: String) throws {
        let url = url(forPluginNamed: name)
        if FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
            try FileManager.default.removeItem(at: url)
        }
    }

    public func url(forPluginNamed name: String) -> URL {
        rootURL.appending(path: PluginPackage.fileName(for: name), directoryHint: .isDirectory)
    }
}
