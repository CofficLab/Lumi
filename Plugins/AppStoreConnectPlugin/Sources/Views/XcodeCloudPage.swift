import LumiUI
import SwiftUI

struct XcodeCloudPage: View {
    @ObservedObject var viewModel: ConnectViewModel

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(
                title: AppStoreConnectLocalization.string("Xcode Cloud"),
                subtitle: viewModel.selectedApp.map { AppStoreConnectLocalization.string("Workflows and build runs for %@", $0.name) } ?? AppStoreConnectLocalization.string("Select an app first")
            )

            HStack(spacing: 10) {
                Picker(AppStoreConnectLocalization.string("Product"), selection: Binding(
                    get: { viewModel.selectedCiProduct?.id ?? "" },
                    set: { id in
                        if let product = viewModel.ciProducts.first(where: { $0.id == id }) {
                            viewModel.selectCiProduct(product)
                        }
                    }
                )) {
                    if viewModel.ciProducts.isEmpty {
                        Text(AppStoreConnectLocalization.string("No Products")).tag("")
                    } else {
                        ForEach(viewModel.ciProducts) { product in
                            Text(product.name).tag(product.id)
                        }
                    }
                }
                .frame(width: 280)

                AppButton(AppStoreConnectLocalization.string("Load Products"), systemImage: "square.and.arrow.down", size: .small) {
                    Task { await viewModel.loadCiProducts() }
                }
                .disabled(!viewModel.credentials.isComplete)

                AppButton(AppStoreConnectLocalization.string("Build Runs"), systemImage: "arrow.clockwise", size: .small) {
                    Task { await viewModel.loadCiBuildRuns() }
                }
                .disabled(viewModel.selectedCiWorkflow == nil)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            if viewModel.ciProducts.isEmpty {
                AppEmptyState(
                    icon: "cloud",
                    title: AppStoreConnectLocalization.string("No Xcode Cloud Products Loaded"),
                    description: AppStoreConnectLocalization.string("Load products from App Store Connect to inspect workflows and start builds.")
                )
            } else {
                HStack(spacing: 0) {
                    workflowList
                        .frame(minWidth: 280, idealWidth: 320, maxWidth: 380)

                    Divider()

                    workflowDetail
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    private var workflowList: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(AppStoreConnectLocalization.string("Workflows"))
                        .font(.headline)
                    Text(viewModel.selectedCiProduct?.bundleID ?? "-")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            List(selection: Binding(
                get: { viewModel.selectedCiWorkflow?.id },
                set: { id in
                    if let id, let workflow = viewModel.ciWorkflows.first(where: { $0.id == id }) {
                        viewModel.selectCiWorkflow(workflow)
                    }
                }
            )) {
                ForEach(viewModel.ciWorkflows) { workflow in
                    CiWorkflowRow(workflow: workflow)
                        .tag(workflow.id)
                }
            }
            .listStyle(.inset)
        }
    }

    @ViewBuilder
    private var workflowDetail: some View {
        if let workflow = viewModel.selectedCiWorkflowDetail ?? viewModel.selectedCiWorkflow {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    AppCard(style: .subtle, cornerRadius: 8, showShadow: false) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(workflow.name)
                                        .font(.title3.weight(.semibold))
                                    Text(workflow.description.isEmpty ? workflow.containerFilePath : workflow.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                CiStatusBadge(
                                    text: workflow.isEnabled ? AppStoreConnectLocalization.string("Enabled") : AppStoreConnectLocalization.string("Disabled"),
                                    color: workflow.isEnabled ? .green : .secondary
                                )
                            }

                            HStack(spacing: 8) {
                                AppButton(
                                    workflow.isEnabled ? AppStoreConnectLocalization.string("Disable Workflow") : AppStoreConnectLocalization.string("Enable Workflow"),
                                    systemImage: workflow.isEnabled ? "pause.fill" : "play.fill",
                                    size: .small
                                ) {
                                    Task { await viewModel.toggleSelectedCiWorkflowEnabled() }
                                }
                                .disabled(viewModel.selectedCiWorkflow == nil)

                                AppButton(AppStoreConnectLocalization.string("Copy Config"), systemImage: "doc.on.doc", size: .small) {
                                    viewModel.copySelectedCiWorkflowConfiguration()
                                }

                                Spacer()
                            }

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), alignment: .leading)], alignment: .leading, spacing: 10) {
                                CiInfoCell(title: AppStoreConnectLocalization.string("Platform"), value: workflow.platformType)
                                CiInfoCell(title: AppStoreConnectLocalization.string("Clean Build"), value: workflow.clean ? AppStoreConnectLocalization.string("Yes") : AppStoreConnectLocalization.string("No"))
                                CiInfoCell(title: AppStoreConnectLocalization.string("Container"), value: workflow.containerFilePath.isEmpty ? "-" : workflow.containerFilePath)
                                CiInfoCell(title: AppStoreConnectLocalization.string("Created"), value: workflow.createdDate.map(ViewFormatting.dateTimeFormatter.string(from:)) ?? "-")
                            }
                        }
                    }

                    AppCard(style: .subtle, cornerRadius: 8, showShadow: false) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(AppStoreConnectLocalization.string("Start Build"))
                                .font(.headline)

                            HStack {
                                GlassTextField(
                                    title: AppStoreConnectLocalization.string("Branch or Tag"),
                                    text: $viewModel.ciSourceBranchOrTag
                                )

                                AppButton(AppStoreConnectLocalization.string("Start Build"), systemImage: "play.fill", style: .primary) {
                                    Task { await viewModel.startCiBuildRun() }
                                }
                                .disabled(!workflow.isEnabled || viewModel.selectedCiWorkflow == nil)
                            }
                        }
                    }

                    AppCard(style: .subtle, cornerRadius: 8, showShadow: false) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(AppStoreConnectLocalization.string("Workflow Config"))
                                    .font(.headline)
                                Spacer()
                                AppButton(AppStoreConnectLocalization.string("Copy"), systemImage: "doc.on.doc", size: .small) {
                                    viewModel.copySelectedCiWorkflowConfiguration()
                                }
                            }

                            Text(viewModel.ciWorkflowExportJSON.isEmpty ? "-" : viewModel.ciWorkflowExportJSON)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(AppStoreConnectLocalization.string("Recent Build Runs"))
                                .font(.headline)
                            Spacer()
                            AppButton(AppStoreConnectLocalization.string("Refresh"), systemImage: "arrow.clockwise", size: .small) {
                                Task { await viewModel.loadCiBuildRuns() }
                            }
                            .disabled(viewModel.selectedCiWorkflow == nil)
                        }

                        if viewModel.ciBuildRuns.isEmpty {
                            AppEmptyState(
                                icon: "hammer",
                                title: AppStoreConnectLocalization.string("No Build Runs"),
                                description: AppStoreConnectLocalization.string("Refresh build runs or start a build for this workflow.")
                            )
                            .frame(minHeight: 180)
                        } else {
                            VStack(spacing: 6) {
                                ForEach(viewModel.ciBuildRuns) { buildRun in
                                    CiBuildRunRow(buildRun: buildRun)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        } else {
            AppEmptyState(
                icon: "point.3.connected.trianglepath.dotted",
                title: AppStoreConnectLocalization.string("No Workflow Selected"),
                description: AppStoreConnectLocalization.string("Choose a workflow to inspect details and recent build runs.")
            )
        }
    }
}

struct CiWorkflowRow: View {
    let workflow: CiWorkflow

    var body: some View {
        AppListRow {
            HStack(spacing: 10) {
                Image(systemName: workflow.isEnabled ? "checkmark.circle.fill" : "pause.circle")
                    .font(.title3)
                    .foregroundStyle(workflow.isEnabled ? .green : .secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 3) {
                    Text(workflow.name)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    Text(workflow.containerFilePath.isEmpty ? workflow.platformType : workflow.containerFilePath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
        }
        .appStoreConnectAddToChatMenu(
            entityType: "ciWorkflow",
            entityID: workflow.id,
            title: workflow.name,
            sourceView: "XcodeCloudPage",
            fields: [
                "containerFilePath": workflow.containerFilePath,
                "isEnabled": workflow.isEnabled ? "true" : "false",
                "platformType": workflow.platformType
            ]
        )
    }
}

struct CiInfoCell: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout)
                .lineLimit(2)
        }
    }
}

struct CiStatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.14), in: Capsule())
            .foregroundStyle(color)
    }
}

struct CiBuildRunRow: View {
    let buildRun: CiBuildRun

    var body: some View {
        AppListRow {
            HStack(spacing: 12) {
                Image(systemName: statusIcon)
                    .font(.title3)
                    .foregroundStyle(statusColor)
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 3) {
                    Text(buildRun.number.map { AppStoreConnectLocalization.string("Build #%d", $0) } ?? buildRun.id)
                        .font(.body.weight(.medium))
                    Text(timeSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                CiStatusBadge(text: statusText, color: statusColor)
            }
        }
        .appStoreConnectAddToChatMenu(
            entityType: "ciBuildRun",
            entityID: buildRun.id,
            title: buildRun.number.map { "Build #\($0)" } ?? buildRun.id,
            sourceView: "XcodeCloudPage",
            fields: [
                "completionStatus": buildRun.completionStatus ?? "-",
                "executionProgress": buildRun.executionProgress,
                "workflowID": buildRun.workflowID ?? "-"
            ]
        )
    }

    private var statusText: String {
        buildRun.completionStatus ?? buildRun.executionProgress
    }

    private var statusIcon: String {
        switch statusText {
        case "SUCCEEDED":
            return "checkmark.circle.fill"
        case "FAILED", "ERRORED":
            return "xmark.octagon.fill"
        case "CANCELED":
            return "stop.circle.fill"
        case "RUNNING":
            return "play.circle.fill"
        default:
            return "clock"
        }
    }

    private var statusColor: Color {
        switch statusText {
        case "SUCCEEDED":
            return .green
        case "FAILED", "ERRORED":
            return .red
        case "CANCELED":
            return .orange
        case "RUNNING":
            return .blue
        default:
            return .secondary
        }
    }

    private var timeSummary: String {
        let created = buildRun.createdDate.map(ViewFormatting.dateTimeFormatter.string(from:)) ?? "-"
        let finished = buildRun.finishedDate.map(ViewFormatting.dateTimeFormatter.string(from:))
        if let finished {
            return AppStoreConnectLocalization.string("Created %@ · Finished %@", created, finished)
        }
        return AppStoreConnectLocalization.string("Created %@", created)
    }
}
