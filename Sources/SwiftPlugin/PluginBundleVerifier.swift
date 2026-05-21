import Foundation

/// Verifies plugins embedded in built app bundles.
public struct PluginBundleVerifier: Sendable {
    private let validator: PluginValidator

    public init(validator: PluginValidator = PluginValidator()) {
        self.validator = validator
    }

    public func verifyAppBundle(at appURL: URL, pluginName: String) throws {
        let pluginRoot = try findPluginRoot(in: appURL, pluginName: pluginName)
        let errors = validator.validationErrors(forPackageAt: pluginRoot)
        if !errors.isEmpty {
            throw PluginValidationFailed(errors: errors)
        }
    }

    public func findPluginRoot(in appURL: URL, pluginName: String) throws -> URL {
        let resourceURL = appURL
            .appending(path: "Contents", directoryHint: .isDirectory)
            .appending(path: "Resources", directoryHint: .isDirectory)

        let fm = FileManager.default
        let resourcePath = resourceURL.path(percentEncoded: false)
        guard fm.fileExists(atPath: resourcePath) else {
            throw PluginValidationFailed(errors: [.missingSupportingFile(resourcePath)])
        }

        guard let enumerator = fm.enumerator(
            at: resourceURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw PluginValidationFailed(errors: [.missingSupportingFile(resourcePath)])
        }

        for case let url as URL in enumerator {
            let packageName = PluginPackage.fileName(for: pluginName)
            guard url.lastPathComponent == packageName || url.lastPathComponent == pluginName else { continue }
            let manifestURL = PluginParser.manifestURL(in: url)
            if fm.fileExists(atPath: manifestURL.path(percentEncoded: false)) {
                return url
            }
        }

        throw PluginValidationFailed(errors: [
            .missingManifest(resourceURL.appending(path: "**/\(PluginPackage.fileName(for: pluginName))/plugin.json"))
        ])
    }
}
