import Foundation
import SwiftSkill

public enum PluginValidationError: Error, Sendable, Hashable, CustomStringConvertible {
    case invalidPackageExtension(URL)
    case missingManifest(URL)
    case invalidManifest(String)
    case invalidTrust(URL, String)
    case missingMCPConfiguration(URL)
    case invalidMCPConfiguration(String)
    case missingCapabilityFile(capability: PluginCapability, path: String)
    case invalidSkill(name: String, errors: [SkillValidationError])
    case duplicateSkillName(String)
    case invalidMCPServerName(String)
    case invalidMCPServer(name: String, reason: String)
    case missingRuntimeDeclaration
    case duplicateRuntimeID(String)
    case missingRuntimeReference(String)
    case invalidRuntime(id: String, reason: String)
    case missingSupportingFile(String)
    case invalidSupportingFilePath(String)
    case missingTrustForExecutableRuntime(String)
    case unresolvedPlaceholder(String)

    public var description: String {
        switch self {
        case .invalidPackageExtension(let url):
            "Invalid plugin package extension: \(url.path(percentEncoded: false))"
        case .missingManifest(let url):
            "Missing plugin manifest: \(url.path(percentEncoded: false))"
        case .invalidManifest(let reason):
            "Invalid plugin manifest: \(reason)"
        case .invalidTrust(let url, let reason):
            "Invalid plugin trust metadata at \(url.path(percentEncoded: false)): \(reason)"
        case .missingMCPConfiguration(let url):
            "Missing MCP configuration: \(url.path(percentEncoded: false))"
        case .invalidMCPConfiguration(let reason):
            "Invalid MCP configuration: \(reason)"
        case .missingCapabilityFile(let capability, let path):
            "Missing file for capability \(capability.rawValue): \(path)"
        case .invalidSkill(let name, let errors):
            "Invalid skill \(name): \(errors)"
        case .duplicateSkillName(let name):
            "Duplicate skill name: \(name)"
        case .invalidMCPServerName(let name):
            "Invalid MCP server name: \(name)"
        case .invalidMCPServer(let name, let reason):
            "Invalid MCP server \(name): \(reason)"
        case .missingRuntimeDeclaration:
            "Missing runtime declaration"
        case .duplicateRuntimeID(let id):
            "Duplicate runtime id: \(id)"
        case .missingRuntimeReference(let id):
            "Missing runtime reference: \(id)"
        case .invalidRuntime(let id, let reason):
            "Invalid runtime \(id): \(reason)"
        case .missingSupportingFile(let path):
            "Missing supporting file: \(path)"
        case .invalidSupportingFilePath(let path):
            "Invalid supporting file path: \(path)"
        case .missingTrustForExecutableRuntime(let runtimeID):
            "Missing trust metadata for executable runtime: \(runtimeID)"
        case .unresolvedPlaceholder(let value):
            "Unresolved placeholder: \(value)"
        }
    }
}
