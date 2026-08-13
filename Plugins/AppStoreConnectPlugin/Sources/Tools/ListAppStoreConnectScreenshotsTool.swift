import Foundation
import KernelLumi

struct ListAppStoreConnectScreenshotsTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "app-store-connect.list-screenshots",
        displayName: "List screenshots",
        description: "List screenshots for a screenshot set."
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "screenshotSetID": .object([
                    "type": .string("string"),
                    "description": .string("The appScreenshotSet id.")
                ])
            ]),
            "required": .array([.string("screenshotSetID")])
        ])
    }

    func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        guard let screenshotSetID = arguments["screenshotSetID"]?.stringValue, !screenshotSetID.isEmpty else {
            return "Missing or empty screenshotSetID."
        }
        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient(kernel: kernel)
        guard let client else { return errorMessage ?? "Failed to initialize App Store Connect client." }
        do {
            let screenshots = try await client.listScreenshots(screenshotSetID: screenshotSetID)
            guard !screenshots.isEmpty else { return "No screenshots found for screenshot set id=\(screenshotSetID)." }
            let lines = screenshots.map { shot in
                let size = shot.fileSize.map(String.init) ?? "unknown"
                return "- \(shot.fileName.isEmpty ? "(unnamed)" : shot.fileName) id=\(shot.id) bytes=\(size)"
            }
            return (["Screenshots for set id=\(screenshotSetID):"] + lines).joined(separator: "\n")
        } catch {
            return "Failed to list screenshots: \(error.localizedDescription)"
        }
    }
}
