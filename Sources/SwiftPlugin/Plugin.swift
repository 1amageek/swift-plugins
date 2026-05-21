import Foundation
import SwiftSkill

/// A complete agent plugin bundle.
public struct Plugin: Sendable, Hashable, Identifiable, Codable {
    public var id: String { manifest.id }

    public var manifest: PluginManifest
    public var mcpConfiguration: MCPConfiguration?
    public var skills: [Skill]
    public var trust: PluginTrust?
    public var supportingFiles: [SupportingFile]
    public var configurations: [String: Data]

    public init(
        manifest: PluginManifest,
        mcpConfiguration: MCPConfiguration? = nil,
        skills: [Skill] = [],
        trust: PluginTrust? = nil,
        supportingFiles: [SupportingFile] = [],
        configurations: [String: Data] = [:]
    ) {
        self.manifest = manifest
        self.mcpConfiguration = mcpConfiguration
        self.skills = skills
        self.trust = trust
        self.supportingFiles = supportingFiles
        self.configurations = configurations
    }
}
