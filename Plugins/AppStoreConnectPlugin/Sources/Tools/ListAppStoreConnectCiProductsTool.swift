import Foundation
import KernelLumi

struct ListAppStoreConnectCiProductsTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "app-store-connect.list-ci-products",
        displayName: "List Xcode Cloud products",
        description: "List Xcode Cloud CI products from App Store Connect."
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([:])
        ])
    }

    func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient(kernel: kernel)
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
