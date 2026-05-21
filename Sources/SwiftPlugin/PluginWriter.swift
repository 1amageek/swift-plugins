import Foundation
import SwiftSkill

/// Writes plugin directory bundles.
public struct PluginWriter: Sendable {
    private let skillWriter: SkillWriter
    private let jsonEncoder: JSONEncoder

    public init(
        skillWriter: SkillWriter = SkillWriter(),
        jsonEncoder: JSONEncoder = JSONEncoder()
    ) {
        self.skillWriter = skillWriter
        self.jsonEncoder = jsonEncoder
        self.jsonEncoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    }

    public func write(_ plugin: Plugin, to url: URL) throws {
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            throw PluginWriterError.directoryCreationFailed(url)
        }

        try writeJSON(plugin.manifest, to: PluginParser.canonicalManifestURL(in: url))
        if let mcpConfiguration = plugin.mcpConfiguration {
            try writeJSON(mcpConfiguration, to: PluginParser.canonicalMCPConfigurationURL(in: url))
        }
        if let trust = plugin.trust {
            try writeJSON(trust, to: PluginParser.trustURL(in: url))
        }

        let skillsRoot = PluginParser.skillsURL(in: url)
        for skill in plugin.skills {
            let skillURL = try PluginPathSecurity.containedURL(root: skillsRoot, relativePath: skill.name)
            try PluginPathSecurity.rejectExistingSymbolicLinkComponents(fileURL: skillURL, rootURL: skillsRoot)
            try validateSupportingFiles(skill.supportingFiles)
            try skillWriter.writeDirectory(skill, to: skillURL)
        }

        for file in plugin.supportingFiles {
            let fileURL = try PluginPathSecurity.containedURL(root: url, relativePath: file.relativePath)
            try PluginPathSecurity.rejectExistingSymbolicLinkComponents(fileURL: fileURL, rootURL: url)
            try fm.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            do {
                try file.content.write(to: fileURL)
            } catch {
                throw PluginWriterError.fileWriteFailed(fileURL, error.localizedDescription)
            }
        }
    }

    private func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        do {
            let data = try jsonEncoder.encode(value)
            try data.write(to: url)
        } catch {
            throw PluginWriterError.fileWriteFailed(url, error.localizedDescription)
        }
    }

    private func validateSupportingFiles(_ files: [SupportingFile]) throws {
        for file in files where !PluginPathSecurity.validateRelativePath(file.relativePath) {
            throw PluginWriterError.unsafePath(file.relativePath)
        }
    }
}
