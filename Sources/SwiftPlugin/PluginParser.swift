import Foundation
import SwiftSkill

/// Reads plugin directory bundles.
public struct PluginParser: Sendable {
    private let skillParser: SkillParser
    private let jsonDecoder: JSONDecoder

    public init(
        skillParser: SkillParser = SkillParser(),
        jsonDecoder: JSONDecoder = JSONDecoder()
    ) {
        self.skillParser = skillParser
        self.jsonDecoder = jsonDecoder
    }

    public func parse(at url: URL) throws -> Plugin {
        let fm = FileManager.default
        let rootPath = url.path(percentEncoded: false)
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: rootPath, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw PluginParserError.pluginDirectoryNotFound(url)
        }
        try rejectPackageSymbolicLinks(at: url)

        let manifestURL = Self.manifestURL(in: url)
        guard fm.fileExists(atPath: manifestURL.path(percentEncoded: false)) else {
            throw PluginParserError.missingManifest(manifestURL)
        }

        let manifest: PluginManifest
        do {
            manifest = try jsonDecoder.decode(PluginManifest.self, from: Data(contentsOf: manifestURL))
        } catch {
            throw PluginParserError.invalidManifest(manifestURL, error.localizedDescription)
        }

        let mcpURL = Self.mcpConfigurationURL(in: url)
        let mcpConfiguration: MCPConfiguration?
        if fm.fileExists(atPath: mcpURL.path(percentEncoded: false)) {
            do {
                mcpConfiguration = try jsonDecoder.decode(MCPConfiguration.self, from: Data(contentsOf: mcpURL))
            } catch {
                throw PluginParserError.invalidMCPConfiguration(mcpURL, error.localizedDescription)
            }
        } else {
            mcpConfiguration = nil
        }

        let skills = try parseSkills(in: url)
        let trust = try parseTrust(in: url)
        let supportingFiles = try collectSupportingFiles(in: url)

        return Plugin(
            manifest: manifest,
            mcpConfiguration: mcpConfiguration,
            skills: skills,
            trust: trust,
            supportingFiles: supportingFiles
        )
    }

    public static func manifestURL(in pluginRootURL: URL) -> URL {
        let canonicalURL = canonicalManifestURL(in: pluginRootURL)
        if FileManager.default.fileExists(atPath: canonicalURL.path(percentEncoded: false)) {
            return canonicalURL
        }
        return legacyManifestURL(in: pluginRootURL)
    }

    public static func mcpConfigurationURL(in pluginRootURL: URL) -> URL {
        let canonicalURL = canonicalMCPConfigurationURL(in: pluginRootURL)
        if FileManager.default.fileExists(atPath: canonicalURL.path(percentEncoded: false)) {
            return canonicalURL
        }
        return legacyMCPConfigurationURL(in: pluginRootURL)
    }

    public static func canonicalManifestURL(in pluginRootURL: URL) -> URL {
        pluginRootURL.appending(path: "plugin.json")
    }

    public static func canonicalMCPConfigurationURL(in pluginRootURL: URL) -> URL {
        pluginRootURL.appending(path: "mcp.json")
    }

    public static func legacyManifestURL(in pluginRootURL: URL) -> URL {
        pluginRootURL
            .appending(path: ".claude-plugin", directoryHint: .isDirectory)
            .appending(path: "plugin.json")
    }

    public static func legacyMCPConfigurationURL(in pluginRootURL: URL) -> URL {
        pluginRootURL.appending(path: ".mcp.json")
    }

    public static func skillsURL(in pluginRootURL: URL) -> URL {
        pluginRootURL.appending(path: "skills", directoryHint: .isDirectory)
    }

    public static func trustURL(in pluginRootURL: URL) -> URL {
        pluginRootURL.appending(path: "trust.json")
    }

    private func parseSkills(in pluginRootURL: URL) throws -> [Skill] {
        let fm = FileManager.default
        let skillsRoot = Self.skillsURL(in: pluginRootURL)
        let skillsPath = skillsRoot.path(percentEncoded: false)
        guard fm.fileExists(atPath: skillsPath) else { return [] }

        let names = try fm.contentsOfDirectory(atPath: skillsPath).sorted()
        var skills: [Skill] = []
        for name in names {
            if name.hasPrefix(".") { continue }
            let skillURL = skillsRoot.appending(path: name, directoryHint: .isDirectory)
            let skillMDURL = skillURL.appending(path: "SKILL.md")
            guard fm.fileExists(atPath: skillMDURL.path(percentEncoded: false)) else { continue }
            skills.append(try skillParser.parseDirectory(at: skillURL))
        }
        return skills
    }

    private func parseTrust(in pluginRootURL: URL) throws -> PluginTrust? {
        let trustURL = Self.trustURL(in: pluginRootURL)
        guard FileManager.default.fileExists(atPath: trustURL.path(percentEncoded: false)) else {
            return nil
        }
        do {
            return try jsonDecoder.decode(PluginTrust.self, from: Data(contentsOf: trustURL))
        } catch {
            throw PluginParserError.invalidTrust(trustURL, error.localizedDescription)
        }
    }

    private func collectSupportingFiles(in pluginRootURL: URL) throws -> [SupportingFile] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: pluginRootURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: []
        ) else {
            return []
        }

        var files: [SupportingFile] = []
        for case let fileURL as URL in enumerator {
            try PluginPathSecurity.rejectSymbolicLink(fileURL)
            let relativePath = try PluginPathSecurity.relativePath(for: fileURL, in: pluginRootURL)
            if shouldSkip(relativePath: relativePath) { continue }

            let values = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
            if values.isDirectory == true {
                continue
            }
            let data = try Data(contentsOf: fileURL)
            files.append(SupportingFile(relativePath: relativePath, content: data))
        }

        return files.sorted { $0.relativePath < $1.relativePath }
    }

    private func rejectPackageSymbolicLinks(at pluginRootURL: URL) throws {
        try PluginPathSecurity.rejectSymbolicLink(pluginRootURL)
        guard let enumerator = FileManager.default.enumerator(
            at: pluginRootURL,
            includingPropertiesForKeys: [.isSymbolicLinkKey],
            options: []
        ) else {
            return
        }
        for case let fileURL as URL in enumerator {
            try PluginPathSecurity.rejectSymbolicLink(fileURL)
        }
    }

    private func shouldSkip(relativePath: String) -> Bool {
        if relativePath == "plugin.json" { return true }
        if relativePath == "mcp.json" { return true }
        if relativePath == "trust.json" { return true }
        if relativePath == ".mcp.json" { return true }
        if relativePath == ".claude-plugin" || relativePath.hasPrefix(".claude-plugin/") { return true }
        if relativePath == "skills" || relativePath.hasPrefix("skills/") { return true }
        if relativePath == ".DS_Store" || relativePath.hasSuffix("/.DS_Store") { return true }
        if relativePath == ".git" || relativePath.hasPrefix(".git/") { return true }
        return false
    }
}
