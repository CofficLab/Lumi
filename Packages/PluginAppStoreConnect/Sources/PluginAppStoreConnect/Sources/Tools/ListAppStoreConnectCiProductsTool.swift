import Foundation
import KernelCore
import KitAgentTool

public struct ListAppStoreConnectCiProductsTool: SuperAgentTool {
    public let name = "app_store_connect_list_ci_products"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "List Xcode Cloud CI products from App Store Connect."
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "List Xcode Cloud products"
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        AppStoreConnectToolSchemaValue.object([
            "type": .string("object"),
            "properties": .object([:])
        ]).dictionaryValue
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient()
        guard let client else { return errorMessage ?? "Failed to initialize App Store Connect client." }
        do {
            let products = try await client.listCiProducts()
            guard !products.isEmpty else { return "No Xcode Cloud products found." }
            let lines = products.map { product in
                "- \(product.name) id=\(product.id) bundleID=\(product.bundleID) type=\(product.productType)"
            }
            return (["Xcode Cloud products:"] + lines).joined(separator: "\n")
        } catch {
            return "Failed to list CI products: \(error.localizedDescription)"
        }
    }
}
