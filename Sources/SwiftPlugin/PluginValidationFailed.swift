import Foundation

public struct PluginValidationFailed: Error, Sendable, LocalizedError {
    public var errors: [PluginValidationError]

    public init(errors: [PluginValidationError]) {
        self.errors = errors
    }

    public var errorDescription: String? {
        errors.map(\.description).joined(separator: "\n")
    }
}
