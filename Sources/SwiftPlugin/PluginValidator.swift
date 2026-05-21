import Foundation
import SwiftSkill

/// Validates plugin values and plugin directories.
public struct PluginValidator: Sendable {
    public var requiresMCPConfiguration: Bool
    public var requiresPackageExtension: Bool
    public var allowsUnresolvedPlaceholders: Bool

    private let skillValidator: SkillValidator

    public init(
        requiresMCPConfiguration: Bool = false,
        requiresPackageExtension: Bool = true,
        allowsUnresolvedPlaceholders: Bool = true,
        skillValidator: SkillValidator = SkillValidator()
    ) {
        self.requiresMCPConfiguration = requiresMCPConfiguration
        self.requiresPackageExtension = requiresPackageExtension
        self.allowsUnresolvedPlaceholders = allowsUnresolvedPlaceholders
        self.skillValidator = skillValidator
    }

    public func validationErrors(for plugin: Plugin) -> [PluginValidationError] {
        var errors: [PluginValidationError] = []

        errors.append(contentsOf: validateManifest(plugin.manifest))
        errors.append(contentsOf: validateSkills(plugin.skills))

        if let mcpConfiguration = plugin.mcpConfiguration {
            errors.append(contentsOf: validateMCPConfiguration(mcpConfiguration))
        } else if requiresMCPConfiguration {
            errors.append(.missingMCPConfiguration(URL(filePath: "mcp.json")))
        }

        errors.append(contentsOf: validateCapabilities(plugin))
        errors.append(contentsOf: validateRuntimes(plugin.manifest.runtimes, plugin: plugin))
        errors.append(contentsOf: validateSupportingFiles(plugin))
        errors.append(contentsOf: validateTrust(plugin.trust, runtimes: plugin.manifest.runtimes))

        return errors
    }

    public func validate(_ plugin: Plugin) throws {
        let errors = validationErrors(for: plugin)
        if !errors.isEmpty {
            throw PluginValidationFailed(errors: errors)
        }
    }

    public func validatePackage(at pluginRootURL: URL) throws {
        let errors = validationErrors(forPackageAt: pluginRootURL)
        if !errors.isEmpty {
            throw PluginValidationFailed(errors: errors)
        }
    }

    public func validationErrors(forPackageAt pluginRootURL: URL) -> [PluginValidationError] {
        var errors: [PluginValidationError] = []
        let fm = FileManager.default
        let manifestURL = PluginParser.canonicalManifestURL(in: pluginRootURL)
        let legacyManifestURL = PluginParser.legacyManifestURL(in: pluginRootURL)
        let mcpURL = PluginParser.canonicalMCPConfigurationURL(in: pluginRootURL)
        let legacyMCPURL = PluginParser.legacyMCPConfigurationURL(in: pluginRootURL)

        if requiresPackageExtension, !PluginPackage.hasFileExtension(pluginRootURL) {
            errors.append(.invalidPackageExtension(pluginRootURL))
        }
        if !fm.fileExists(atPath: manifestURL.path(percentEncoded: false)),
           !fm.fileExists(atPath: legacyManifestURL.path(percentEncoded: false)) {
            errors.append(.missingManifest(manifestURL))
        }
        if requiresMCPConfiguration,
           !fm.fileExists(atPath: mcpURL.path(percentEncoded: false)),
           !fm.fileExists(atPath: legacyMCPURL.path(percentEncoded: false)) {
            errors.append(.missingMCPConfiguration(mcpURL))
        }

        do {
            let plugin = try PluginParser().parse(at: pluginRootURL)
            errors.append(contentsOf: validationErrors(for: plugin))
        } catch let error as PluginParserError {
            errors.append(.invalidManifest(error.localizedDescription))
        } catch {
            errors.append(.invalidManifest(error.localizedDescription))
        }

        return stable(errors)
    }

    private func validateManifest(_ manifest: PluginManifest) -> [PluginValidationError] {
        var errors: [PluginValidationError] = []
        if manifest.schemaVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.invalidManifest("schemaVersion is required"))
        }
        if manifest.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.invalidManifest("id is required"))
        }
        if manifest.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.invalidManifest("name is required"))
        }
        if manifest.name.contains("/") || manifest.name.contains(":") {
            errors.append(.invalidManifest("name must be a path-safe identifier"))
        }
        if manifest.displayName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
            errors.append(.invalidManifest("displayName is required"))
        }
        if manifest.version?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
            errors.append(.invalidManifest("version is required"))
        }
        if manifest.capabilities.isEmpty {
            errors.append(.invalidManifest("capabilities must not be empty"))
        }
        return errors
    }

    private func validateCapabilities(_ plugin: Plugin) -> [PluginValidationError] {
        var errors: [PluginValidationError] = []
        let capabilities = Set(plugin.manifest.capabilities)

        if capabilities.contains(.skill), plugin.skills.isEmpty {
            errors.append(.missingCapabilityFile(capability: .skill, path: "skills/"))
        }
        if capabilities.contains(.mcp), plugin.mcpConfiguration == nil {
            errors.append(.missingMCPConfiguration(URL(filePath: "mcp.json")))
        }
        if capabilities.contains(.runtime), plugin.manifest.runtimes.isEmpty {
            errors.append(.missingRuntimeDeclaration)
        }

        return errors
    }

    private func validateSkills(_ skills: [Skill]) -> [PluginValidationError] {
        var errors: [PluginValidationError] = []
        var seen: Set<String> = []

        for skill in skills {
            if !seen.insert(skill.name).inserted {
                errors.append(.duplicateSkillName(skill.name))
            }

            let skillErrors = skillValidator.validate(skill)
            if !skillErrors.isEmpty {
                errors.append(.invalidSkill(name: skill.name, errors: skillErrors))
            }
        }

        return errors
    }

    private func validateMCPConfiguration(_ configuration: MCPConfiguration) -> [PluginValidationError] {
        var errors: [PluginValidationError] = []
        if configuration.servers.isEmpty {
            errors.append(.invalidMCPConfiguration("mcpServers must not be empty"))
        }

        for (name, server) in configuration.servers.sorted(by: { $0.key < $1.key }) {
            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append(.invalidMCPServerName(name))
            }

            switch server.type {
            case .stdio:
                if (server.command?.isEmpty ?? true) && (server.runtimeRef?.isEmpty ?? true) {
                    errors.append(.invalidMCPServer(name: name, reason: "stdio servers require command"))
                }
            case .http, .streamableHTTP:
                if server.url?.isEmpty ?? true {
                    errors.append(.invalidMCPServer(name: name, reason: "\(server.type.rawValue) servers require url"))
                }
            }

            if !allowsUnresolvedPlaceholders {
                errors.append(contentsOf: unresolvedPlaceholders(in: server))
            }
        }

        return errors
    }

    private func validateRuntimes(_ runtimes: [PluginRuntime], plugin: Plugin) -> [PluginValidationError] {
        var errors: [PluginValidationError] = []
        var runtimeIDs: Set<String> = []
        let supportingFilePaths = Set(plugin.supportingFiles.map(\.relativePath))

        for runtime in runtimes {
            if runtime.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append(.invalidRuntime(id: runtime.id, reason: "id is required"))
            }
            if !runtimeIDs.insert(runtime.id).inserted {
                errors.append(.duplicateRuntimeID(runtime.id))
            }
            if let entrypoint = runtime.entrypoint {
                errors.append(contentsOf: validateRelativePath(entrypoint, runtimeID: runtime.id, field: "entrypoint"))
            }
            if let workingDirectory = runtime.workingDirectory {
                errors.append(contentsOf: validateRelativePath(workingDirectory, runtimeID: runtime.id, field: "workingDirectory"))
            }
            if runtime.kind == .node || runtime.kind == .binary {
                if runtime.entrypoint?.isEmpty ?? true {
                    errors.append(.invalidRuntime(id: runtime.id, reason: "\(runtime.kind.rawValue) runtime requires entrypoint"))
                }
                if let entrypoint = runtime.entrypoint, !supportingFilePaths.contains(entrypoint) {
                    errors.append(.missingSupportingFile(entrypoint))
                }
            }
        }

        let referencedRuntimeIDs = plugin.mcpConfiguration?.servers.values.compactMap(\.runtimeRef) ?? []
        for runtimeID in referencedRuntimeIDs where !runtimeIDs.contains(runtimeID) {
            errors.append(.missingRuntimeReference(runtimeID))
        }

        return errors
    }

    private func validateRelativePath(
        _ path: String,
        runtimeID: String,
        field: String
    ) -> [PluginValidationError] {
        if path.hasPrefix("/") || path.split(separator: "/").contains("..") {
            return [.invalidRuntime(id: runtimeID, reason: "\(field) must be package-relative")]
        }
        return []
    }

    private func validateSupportingFiles(_ plugin: Plugin) -> [PluginValidationError] {
        var errors: [PluginValidationError] = []

        for file in plugin.supportingFiles where !PluginPathSecurity.validateRelativePath(file.relativePath) {
            errors.append(.invalidSupportingFilePath(file.relativePath))
        }

        for skill in plugin.skills {
            for file in skill.supportingFiles where !PluginPathSecurity.validateRelativePath(file.relativePath) {
                errors.append(.invalidSupportingFilePath("skills/\(skill.name)/\(file.relativePath)"))
            }
        }

        return errors
    }

    private func validateTrust(_ trust: PluginTrust?, runtimes: [PluginRuntime]) -> [PluginValidationError] {
        var errors: [PluginValidationError] = []
        let executableRuntimes = runtimes.filter { $0.kind == .node || $0.kind == .binary }

        for runtime in executableRuntimes {
            guard let trust else {
                errors.append(.missingTrustForExecutableRuntime(runtime.id))
                continue
            }
            if trust.digests.isEmpty {
                errors.append(.invalidTrust(URL(filePath: "trust.json"), "digests must not be empty for executable runtimes"))
            }
        }

        guard let trust else { return errors }
        for (path, digest) in trust.digests {
            if !PluginPathSecurity.validateRelativePath(path) {
                errors.append(.invalidTrust(URL(filePath: "trust.json"), "digest path must be package-relative: \(path)"))
            }
            if digest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append(.invalidTrust(URL(filePath: "trust.json"), "digest value must not be empty: \(path)"))
            }
        }

        return errors
    }

    private func unresolvedPlaceholders(in server: MCPServer) -> [PluginValidationError] {
        var values: [String] = []
        if let command = server.command { values.append(command) }
        if let url = server.url { values.append(url) }
        values.append(contentsOf: server.args ?? [])
        values.append(contentsOf: server.environment.values)

        return values
            .filter { $0.contains("${") }
            .map { .unresolvedPlaceholder($0) }
    }

    private func stable(_ errors: [PluginValidationError]) -> [PluginValidationError] {
        errors.sorted { $0.description < $1.description }
    }
}
