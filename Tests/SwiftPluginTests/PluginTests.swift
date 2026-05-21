import Foundation
import SwiftPlugin
import SwiftSkill
import Testing

@Suite("Plugin parsing and validation")
struct PluginTests {
    @Test
    func parsesValidPluginDirectory() throws {
        let root = try makePluginDirectory()

        let plugin = try PluginParser().parse(at: root)
        #expect(plugin.id == "com.salescore.aurora.memory")
        #expect(plugin.manifest.name == "aurora")
        #expect(plugin.manifest.capabilities == [.skill, .mcp, .runtime])
        #expect(plugin.mcpConfiguration?.servers["memory"]?.type == .stdio)
        #expect(plugin.mcpConfiguration?.servers["memory"]?.runtimeRef == "memory-server")
        #expect(plugin.skills.map(\.name) == ["memory-mcp"])
        #expect(plugin.trust?.provenance == "marketplace")

        let errors = PluginValidator().validationErrors(for: plugin)
        #expect(errors.isEmpty)
    }

    @Test
    func reportsMissingMCPConfiguration() throws {
        let root = try makePluginDirectory(includeMCP: false)

        let errors = PluginValidator().validationErrors(forPackageAt: root)
        #expect(errors.contains {
            if case .missingMCPConfiguration = $0 { return true }
            return false
        })
    }

    @Test
    func writesCanonicalPluginPackageFiles() throws {
        let source = try makePluginDirectory()
        let plugin = try PluginParser().parse(at: source)
        let destination = try temporaryDirectory().appending(path: "installed", directoryHint: .isDirectory)

        try PluginWriter().write(plugin, to: destination)

        #expect(FileManager.default.fileExists(atPath: destination.appending(path: "mcp.json").path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: destination.appending(path: "plugin.json").path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: destination.appending(path: "trust.json").path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: destination.appending(path: "skills/memory-mcp/SKILL.md").path(percentEncoded: false)))
    }

    @Test
    func materializesClaudeCompatibilityFilesFromCanonicalPackage() throws {
        let source = try makePluginDirectory()
        let plugin = try PluginParser().parse(at: source)
        let destination = try temporaryDirectory().appending(path: "installed.plugin", directoryHint: .isDirectory)

        try PluginWriter().write(plugin, to: destination)
        try PluginMaterializer().materializeCompatibilityFiles(for: plugin, provider: .claude, at: destination)

        let mcpURL = destination.appending(path: ".mcp.json")
        let manifestURL = destination.appending(path: ".claude-plugin/plugin.json")
        #expect(FileManager.default.fileExists(atPath: mcpURL.path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: manifestURL.path(percentEncoded: false)))

        let manifestData = try Data(contentsOf: manifestURL)
        let manifest = try JSONSerialization.jsonObject(with: manifestData) as? [String: Any]
        #expect(manifest?["name"] as? String == "aurora")
        #expect(manifest?["mcpServers"] as? String == "./.mcp.json")
        #expect(manifest?["schemaVersion"] == nil)
    }

    @Test
    func installsIntoPluginPackageDirectory() throws {
        let source = try makePluginDirectory()
        let destinationRoot = try temporaryDirectory()

        let installedURL = try PluginInstaller(destinationRootURL: destinationRoot).install(from: source)

        #expect(installedURL.lastPathComponent == "aurora.plugin")
        #expect(FileManager.default.fileExists(atPath: installedURL.appending(path: "plugin.json").path(percentEncoded: false)))
    }

    @Test
    func reportsInvalidPackageExtension() throws {
        let root = try makePluginDirectory(packageName: "aurora")

        let errors = PluginValidator().validationErrors(forPackageAt: root)
        #expect(errors.contains {
            if case .invalidPackageExtension = $0 { return true }
            return false
        })
    }

    @Test
    func installerRejectsNonPluginSourceDirectory() throws {
        let root = try makePluginDirectory(packageName: "aurora")
        let destinationRoot = try temporaryDirectory()

        #expect(throws: PluginValidationFailed.self) {
            try PluginInstaller(destinationRootURL: destinationRoot).install(from: root)
        }
    }

    @Test
    func rejectsUnsafeSupportingFilePaths() throws {
        let plugin = Plugin(
            manifest: PluginManifest(
                id: "com.salescore.aurora.memory",
                name: "aurora",
                displayName: "AURORA",
                version: "0.1.0",
                capabilities: [.resource]
            ),
            supportingFiles: [
                SupportingFile(relativePath: "../escape.txt", text: "escape")
            ]
        )

        let errors = PluginValidator().validationErrors(for: plugin)
        #expect(errors.contains {
            if case .invalidSupportingFilePath = $0 { return true }
            return false
        })
        #expect(throws: PluginWriterError.self) {
            try PluginWriter().write(plugin, to: temporaryDirectory().appending(path: "bad.plugin"))
        }
    }

    @Test
    func rejectsSymlinksInsidePackage() throws {
        let root = try makePluginDirectory()
        let target = try temporaryDirectory().appending(path: "outside.txt")
        try Data("outside".utf8).write(to: target)
        let symlink = root.appending(path: "resources/link.txt")
        try FileManager.default.createDirectory(at: symlink.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: target)

        #expect(throws: PluginParserError.self) {
            try PluginParser().parse(at: root)
        }
    }

    @Test
    func requiresTrustDigestForExecutableRuntime() throws {
        let root = try makePluginDirectory(includeTrustDigest: false)

        let errors = PluginValidator().validationErrors(forPackageAt: root)
        #expect(errors.contains {
            if case .invalidTrust = $0 { return true }
            return false
        })
    }
}

private func makePluginDirectory(
    packageName: String = "aurora.plugin",
    includeMCP: Bool = true,
    includeTrustDigest: Bool = true
) throws -> URL {
    let root = try temporaryDirectory().appending(path: packageName, directoryHint: .isDirectory)
    let fm = FileManager.default
    try fm.createDirectory(at: root.appending(path: "skills/memory-mcp", directoryHint: .isDirectory), withIntermediateDirectories: true)
    try fm.createDirectory(at: root.appending(path: "runtimes/memory-server/dist", directoryHint: .isDirectory), withIntermediateDirectories: true)

    try Data("""
    {
      "schemaVersion": "1",
      "id": "com.salescore.aurora.memory",
      "name": "aurora",
      "displayName": "AURORA",
      "version": "0.1.0",
      "capabilities": ["skill", "mcp", "runtime"],
      "runtimes": [
        {
          "id": "memory-server",
          "kind": "node",
          "entrypoint": "runtimes/memory-server/dist/server.js",
          "requiredVersion": ">=20"
        }
      ]
    }
    """.utf8).write(to: root.appending(path: "plugin.json"))

    try Data("""
    {
      "provenance": "marketplace",
      "digests": {
        "runtimes/memory-server/dist/server.js": "\(includeTrustDigest ? "sha256:fixture" : "")"
      }
    }
    """.utf8).write(to: root.appending(path: "trust.json"))

    if includeMCP {
        try Data("""
        {
          "mcpServers": {
            "memory": {
              "type": "stdio",
              "runtimeRef": "memory-server"
            }
          }
        }
        """.utf8).write(to: root.appending(path: "mcp.json"))
    }

    try Data("""
    console.log("memory");
    """.utf8).write(to: root.appending(path: "runtimes/memory-server/dist/server.js"))

    try Data("""
    ---
    name: memory-mcp
    description: Connect to the AURORA memory MCP server.
    ---
    Use the memory MCP server.
    """.utf8).write(to: root.appending(path: "skills/memory-mcp/SKILL.md"))

    return root
}

private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "swift-plugin-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
