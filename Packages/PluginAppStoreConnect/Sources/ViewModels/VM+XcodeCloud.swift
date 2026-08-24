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
            ciWorkflows = try await client.listCiWorkflows(productID: product.id)
            selectedCiWorkflow = ciWorkflows.first
            if selectedCiWorkflow != nil {
                await loadSelectedCiWorkflowDetail()
            } else {
                selectedCiWorkflowDetail = nil
                ciBuildRuns = []
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
            selectedCiWorkflowDetail = try await client.readCiWorkflow(id: workflow.id)
            ciBuildRuns = try await client.listCiBuildRuns(workflowID: workflow.id)
            updateCiWorkflowExportJSON()
        }
    }

    func loadCiBuildRuns() async {
        guard let workflow = selectedCiWorkflow else { return }
        await runBusy {
            ciBuildRuns = try await client.listCiBuildRuns(workflowID: workflow.id)
        }
    }

    func startCiBuildRun() async {
        guard let workflow = selectedCiWorkflow else { return }
        await runBusy {
            let buildRun = try await client.startCiBuildRun(
                workflowID: workflow.id,
                branch: ciSourceBranchOrTag
            )
            ciBuildRuns.insert(buildRun, at: 0)
            ciBuildRuns = try await client.listCiBuildRuns(workflowID: workflow.id)
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
