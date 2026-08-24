import Foundation

extension ConnectClient {
    // MARK: - CI Products & Workflows

    func listCiProducts() async throws -> [CiProduct] {
        let query = [
            URLQueryItem(name: "limit", value: "200"),
            // App Store Connect API rejects `primaryApp` in fields[ciProducts] (invalid field name).
            // Keep `include=primaryApp` for relationship resolution when available.
            URLQueryItem(name: "fields[ciProducts]", value: "name,createdDate,productType,bundleId,app,workflows"),
            URLQueryItem(name: "include", value: "app,primaryApp")
        ]
        let response: AppStoreConnectListResponse<CiProduct> = try await request(
            path: "/v1/ciProducts",
            queryItems: query
        )
        return response.data.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func listCiWorkflows(productID: String) async throws -> [CiWorkflow] {
        let query = [
            URLQueryItem(name: "limit", value: "200"),
            URLQueryItem(
                name: "fields[ciWorkflows]",
                value: "name,description,isEnabled,clean,containerFilePath,platformType,createdDate"
            )
        ]
        let response: AppStoreConnectListResponse<CiWorkflow> = try await request(
            path: "/v1/ciProducts/\(productID)/workflows",
            queryItems: query
        )
        return response.data.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func readCiWorkflow(id: String) async throws -> CiWorkflow {
        let query = [
            URLQueryItem(
                name: "fields[ciWorkflows]",
                value: "name,description,isEnabled,clean,containerFilePath,platformType,createdDate"
            )
        ]
        let response: AppStoreConnectSingleResponse<CiWorkflow> = try await request(
            path: "/v1/ciWorkflows/\(id)",
            queryItems: query
        )
        return response.data
    }

    // MARK: - CI Build Runs

    func listCiBuildRuns(workflowID: String, limit: Int = 20) async throws -> [CiBuildRun] {
        let query = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(
                name: "fields[ciBuildRuns]",
                value: "number,createdDate,startedDate,finishedDate,isPullRequestBuild,executionProgress,completionStatus,workflow"
            )
        ]
        let response: AppStoreConnectListResponse<CiBuildRun> = try await request(
            path: "/v1/ciWorkflows/\(workflowID)/buildRuns",
            queryItems: query
        )
        return response.data.sorted {
            ($0.createdDate ?? .distantPast) > ($1.createdDate ?? .distantPast)
        }
    }

    func startCiBuildRun(workflowID: String, branch: String) async throws -> CiBuildRun {
        let body = try Self.makeCiBuildRunCreateBody(workflowID: workflowID, branch: branch)
        let response: AppStoreConnectSingleResponse<CiBuildRun> = try await request(
            path: "/v1/ciBuildRuns",
            method: "POST",
            body: body
        )
        return response.data
    }

    // MARK: - CI Workflow Updates

    func updateCiWorkflowEnabled(id: String, isEnabled: Bool) async throws -> CiWorkflow {
        let body = try Self.makeCiWorkflowEnabledUpdateBody(id: id, isEnabled: isEnabled)
        let response: AppStoreConnectSingleResponse<CiWorkflow> = try await request(
            path: "/v1/ciWorkflows/\(id)",
            method: "PATCH",
            body: body
        )
        return response.data
    }

    // MARK: - Request Body Helpers

    static func makeCiBuildRunCreateBody(workflowID: String, branch: String) throws -> Data {
        var attributes: [String: Any] = [:]
        let sourceBranchOrTag = branch.trimmingCharacters(in: .whitespacesAndNewlines)
        if !sourceBranchOrTag.isEmpty {
            attributes["sourceBranchOrTag"] = sourceBranchOrTag
        }

        var data: [String: Any] = [
            "type": "ciBuildRuns",
            "relationships": [
                "workflow": [
                    "data": [
                        "type": "ciWorkflows",
                        "id": workflowID
                    ]
                ]
            ]
        ]
        if !attributes.isEmpty {
            data["attributes"] = attributes
        }

        return try JSONSerialization.data(withJSONObject: ["data": data])
    }

    static func makeCiWorkflowEnabledUpdateBody(id: String, isEnabled: Bool) throws -> Data {
        let payload: [String: Any] = [
            "data": [
                "id": id,
                "type": "ciWorkflows",
                "attributes": [
                    "isEnabled": isEnabled
                ]
            ]
        ]
        return try JSONSerialization.data(withJSONObject: payload)
    }
}
