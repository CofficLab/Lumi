import AppKit
import Foundation

extension VM {
    func loadCiProducts() async {
        await runBusy {
            ciProducts = try await client.listCiProducts()
            selectBestCiProduct()
            if selectedCiProduct != nil {
                await loadCiWorkflows()
            }
        }
    }

    func selectCiProduct(_ product: CiProduct) {
        selectedCiProduct = product
        ciWorkflows = []
        selectedCiWorkflow = nil
        selectedCiWorkflowDetail = nil
        ciBuildRuns = []
        ciWorkflowExportJSON = ""
        Task { await loadCiWorkflows() }
    }

    func loadCiWorkflows() async {
        guard let product = selectedCiProduct else { return }
        await runBusy {
            let workflows = try await client.listCiWorkflows(productID: product.id)
            guard applyCiWorkflowsResponse(workflows, forProductID: product.id) else { return }
            if selectedCiWorkflow != nil {
                await loadSelectedCiWorkflowDetail()
            }
        }
    }

    func selectCiWorkflow(_ workflow: CiWorkflow) {
        selectedCiWorkflow = workflow
        selectedCiWorkflowDetail = nil
        ciBuildRuns = []
        ciWorkflowExportJSON = ""
        Task { await loadSelectedCiWorkflowDetail() }
    }

    func loadSelectedCiWorkflowDetail() async {
        guard let workflow = selectedCiWorkflow else { return }
        await runBusy {
            let detail = try await client.readCiWorkflow(id: workflow.id)
            guard applyCiWorkflowDetailResponse(detail, forWorkflowID: workflow.id) else { return }
            let buildRuns = try await client.listCiBuildRuns(workflowID: workflow.id)
            _ = applyCiBuildRunsResponse(buildRuns, forWorkflowID: workflow.id)
            updateCiWorkflowExportJSON()
        }
    }

    func loadCiBuildRuns() async {
        guard let workflow = selectedCiWorkflow else { return }
        await runBusy {
            let buildRuns = try await client.listCiBuildRuns(workflowID: workflow.id)
            _ = applyCiBuildRunsResponse(buildRuns, forWorkflowID: workflow.id)
        }
    }

    func startCiBuildRun() async {
        guard let workflow = selectedCiWorkflow else { return }
        await runBusy {
            let buildRun = try await client.startCiBuildRun(
                workflowID: workflow.id,
                branch: ciSourceBranchOrTag
            )
            guard selectedCiWorkflow?.id == workflow.id else {
                Self.logger.info("\(self.t)discarded build run started for stale workflow: \(workflow.id)")
                return
            }
            ciBuildRuns.insert(buildRun, at: 0)
            let buildRuns = try await client.listCiBuildRuns(workflowID: workflow.id)
            _ = applyCiBuildRunsResponse(buildRuns, forWorkflowID: workflow.id)
        }
    }

    func toggleSelectedCiWorkflowEnabled() async {
        guard let workflow = selectedCiWorkflowDetail ?? selectedCiWorkflow else { return }
        await runBusy {
            let updated = try await client.updateCiWorkflowEnabled(id: workflow.id, isEnabled: !workflow.isEnabled)
            replaceCiWorkflow(updated)
            selectedCiWorkflow = updated
            selectedCiWorkflowDetail = updated
            updateCiWorkflowExportJSON()
        }
    }

    func copySelectedCiWorkflowConfiguration() {
        updateCiWorkflowExportJSON()
        guard !ciWorkflowExportJSON.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(ciWorkflowExportJSON, forType: .string)
    }

    func reloadCiProductsFromNetwork() async throws {
        ciProducts = try await client.listCiProducts()
        selectBestCiProduct()
        if selectedCiProduct != nil {
            try await reloadCiWorkflowsFromNetwork()
        }
    }

    func reloadCiWorkflowsFromNetwork() async throws {
        guard let product = selectedCiProduct else { return }
        ciWorkflows = try await client.listCiWorkflows(productID: product.id)
        if let current = selectedCiWorkflow,
           !ciWorkflows.contains(where: { $0.id == current.id }) {
            selectedCiWorkflow = ciWorkflows.first
        }
        updateCiWorkflowExportJSON()
    }

    func reloadSelectedCiWorkflowDetailFromNetwork() async throws {
        guard let workflow = selectedCiWorkflow else { return }
        let detail = try await client.readCiWorkflow(id: workflow.id)
        selectedCiWorkflowDetail = detail
        replaceCiWorkflow(detail)
        ciBuildRuns = try await client.listCiBuildRuns(workflowID: detail.id)
        updateCiWorkflowExportJSON()
    }

    func clearXcodeCloudSelection() {
        selectedCiProduct = nil
        ciWorkflows = []
        selectedCiWorkflow = nil
        selectedCiWorkflowDetail = nil
        ciBuildRuns = []
        ciWorkflowExportJSON = ""
    }

    func clearXcodeCloudState() {
        ciProducts = []
        clearXcodeCloudSelection()
        ciSourceBranchOrTag = ""
    }

    func selectBestCiProduct() {
        guard selectedCiProduct == nil else { return }
        guard let selectedApp else {
            selectedCiProduct = ciProducts.first
            return
        }
        selectedCiProduct = ciProducts.first {
            $0.appID == selectedApp.id ||
            $0.primaryAppID == selectedApp.id ||
            $0.bundleID == selectedApp.bundleID
        } ?? ciProducts.first
    }

    func replaceCiWorkflow(_ workflow: CiWorkflow) {
        if let index = ciWorkflows.firstIndex(where: { $0.id == workflow.id }) {
            ciWorkflows[index] = workflow
        }
    }

    /// 应用工作流列表响应：切换过 App 或产品后，迟到的响应会被丢弃（#434）。
    @discardableResult
    func applyCiWorkflowsResponse(_ workflows: [CiWorkflow], forProductID productID: String) -> Bool {
        guard selectedCiProduct?.id == productID else {
            Self.logger.info("\(self.t)discarded stale workflows for product: \(productID)")
            return false
        }
        ciWorkflows = workflows
        selectedCiWorkflow = ciWorkflows.first
        if selectedCiWorkflow == nil {
            selectedCiWorkflowDetail = nil
            ciBuildRuns = []
        }
        return true
    }

    /// 应用工作流详情响应：切换过工作流后，迟到的响应会被丢弃（#434）。
    @discardableResult
    func applyCiWorkflowDetailResponse(_ detail: CiWorkflow, forWorkflowID workflowID: String) -> Bool {
        guard selectedCiWorkflow?.id == workflowID else {
            Self.logger.info("\(self.t)discarded stale workflow detail for: \(workflowID)")
            return false
        }
        selectedCiWorkflowDetail = detail
        return true
    }

    /// 应用构建列表响应：切换过工作流后，迟到的响应会被丢弃（#434）。
    @discardableResult
    func applyCiBuildRunsResponse(_ buildRuns: [CiBuildRun], forWorkflowID workflowID: String) -> Bool {
        guard selectedCiWorkflow?.id == workflowID else {
            Self.logger.info("\(self.t)discarded stale build runs for: \(workflowID)")
            return false
        }
        ciBuildRuns = buildRuns
        return true
    }

    func updateCiWorkflowExportJSON() {
        guard let workflow = selectedCiWorkflowDetail ?? selectedCiWorkflow,
              let data = try? JSONEncoder.xcodeCloudExport.encode(CiWorkflowExport(workflow: workflow)),
              let value = String(data: data, encoding: .utf8) else {
            ciWorkflowExportJSON = ""
            return
        }
        ciWorkflowExportJSON = value
    }
}

private extension JSONEncoder {
    static var xcodeCloudExport: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}
