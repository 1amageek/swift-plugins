import Foundation

/// Filename helpers for `.plugin` directory packages.
public enum PluginPackage {
    public static let pathExtension = "plugin"

    public static func hasFileExtension(_ url: URL) -> Bool {
        url.pathExtension == pathExtension
    }

    public static func fileName(for pluginName: String) -> String {
        if pluginName.hasSuffix(".\(pathExtension)") {
            return pluginName
        }
        return "\(pluginName).\(pathExtension)"
    }
}
