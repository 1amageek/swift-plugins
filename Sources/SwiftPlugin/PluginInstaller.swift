import Foundation

/// Installs validated plugins into a runtime plugin root.
public struct PluginInstaller: Sendable {
    public let destinationRootURL: URL

    private let parser: PluginParser
    private let writer: PluginWriter
    private let validator: PluginValidator

    public init(
        destinationRootURL: URL,
        parser: PluginParser = PluginParser(),
        writer: PluginWriter = PluginWriter(),
        validator: PluginValidator = PluginValidator()
    ) {
        self.destinationRootURL = destinationRootURL
        self.parser = parser
        self.writer = writer
        self.validator = validator
    }

    @discardableResult
    public func install(_ plugin: Plugin) throws -> URL {
        try validator.validate(plugin)

        let destinationURL = destinationRootURL.appending(
            path: PluginPackage.fileName(for: plugin.manifest.name),
            directoryHint: .isDirectory
        )
        let fm = FileManager.default
        try fm.createDirectory(at: destinationRootURL, withIntermediateDirectories: true)

        let temporaryURL = destinationRootURL.appending(
            path: ".install-\(UUID().uuidString)-\(destinationURL.lastPathComponent)",
            directoryHint: .isDirectory
        )
        let backupURL = destinationRootURL.appending(
            path: ".backup-\(UUID().uuidString)-\(destinationURL.lastPathComponent)",
            directoryHint: .isDirectory
        )

        do {
            try writer.write(plugin, to: temporaryURL)
            let temporaryErrors = validator.validationErrors(forPackageAt: temporaryURL)
            if !temporaryErrors.isEmpty {
                throw PluginValidationFailed(errors: temporaryErrors)
            }

            if fm.fileExists(atPath: destinationURL.path(percentEncoded: false)) {
                try fm.moveItem(at: destinationURL, to: backupURL)
            }

            do {
                try fm.moveItem(at: temporaryURL, to: destinationURL)
            } catch {
                if fm.fileExists(atPath: backupURL.path(percentEncoded: false)),
                   !fm.fileExists(atPath: destinationURL.path(percentEncoded: false)) {
                    try fm.moveItem(at: backupURL, to: destinationURL)
                }
                throw error
            }

            if fm.fileExists(atPath: backupURL.path(percentEncoded: false)) {
                try fm.removeItem(at: backupURL)
            }
        } catch {
            if fm.fileExists(atPath: temporaryURL.path(percentEncoded: false)) {
                try fm.removeItem(at: temporaryURL)
            }
            if fm.fileExists(atPath: backupURL.path(percentEncoded: false)),
               !fm.fileExists(atPath: destinationURL.path(percentEncoded: false)) {
                try fm.moveItem(at: backupURL, to: destinationURL)
            }
            throw error
        }

        return destinationURL
    }

    @discardableResult
    public func install(from sourceURL: URL) throws -> URL {
        try validator.validatePackage(at: sourceURL)
        let plugin = try parser.parse(at: sourceURL)
        return try install(plugin)
    }
}
