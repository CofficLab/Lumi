import Foundation
import SuperLogKit

public struct TSLSPConfig: SuperLog {
    public nonisolated static let emoji = "🟦"

    public struct ServerConfig: Sendable {
        public let executablePath: String
        public let arguments: [String]
        public let environment: [String: String]
        public let initializationOptions: [String: String]
    }

    public static func config(projectPath: String?) -> ServerConfig? {
        guard let executablePath = JSEnvResolver.findCommand("typescript-language-server") else {
            return nil
        }

        var options: [String: String] = [
            "hostInfo": "Lumi",
            "preferences.includePackageJsonAutoImports": "on",
            "preferences.includeCompletionsForModuleExports": "true",
            "preferences.includeCompletionsForImportStatements": "true",
        ]

        if let projectPath, let tsconfig = TSConfigResolver.resolve(projectPath: projectPath) {
            options["compilerOptions.moduleResolution"] = tsconfig.moduleResolution ?? ""
            options["compilerOptions.jsx"] = tsconfig.jsx ?? ""
            options["compilerOptions.strict"] = tsconfig.strict.map(String.init) ?? ""
        }

        return ServerConfig(
            executablePath: executablePath,
            arguments: ["--stdio"],
            environment: [:],
            initializationOptions: options.filter { !$0.value.isEmpty }
        )
    }
}
