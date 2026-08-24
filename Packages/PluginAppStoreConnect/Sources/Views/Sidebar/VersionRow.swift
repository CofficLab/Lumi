import LumiUI
import SwiftUI

struct SidebarVersionRow: View {
    let version: AppStoreVersion
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        AppSidebarRow(
            title: version.versionString,
            systemImage: version.stateIcon,
            leadingColor: version.stateColor,
            isSelected: isSelected,
            action: action
        ) {
            Text(version.shortStateLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .appStoreConnectAddToChatMenu(
            entityType: "version",
            entityID: version.id,
            title: version.versionString,
            sourceView: "SidebarVersionRow",
            fields: [
                "appStoreState": version.appStoreState,
                "platform": version.platform
            ]
        )
    }
}

private extension AppStoreVersion {
    var shortStateLabel: String {
        let state = appStoreState.uppercased()
        if state == "PENDING_DEVELOPER_RELEASE" {
            return AppStoreConnectLocalization.string("Pending Developer Release")
        }
        if state.contains("READY") { return AppStoreConnectLocalization.string("Ready") }
        if state.contains("PREPARE") { return AppStoreConnectLocalization.string("Prepare") }
        if state.contains("REJECT") { return AppStoreConnectLocalization.string("Rejected") }
        if state.contains("REVIEW") { return AppStoreConnectLocalization.string("In Review") }
        if state.contains("REPLACED") { return AppStoreConnectLocalization.string("Replaced") }
        return localizedAppStoreStateLabel
    }

    var appStoreStateLabel: String {
        localizedAppStoreStateLabel
    }

    var stateIcon: String {
        let state = appStoreState.uppercased()
        if state.contains("REJECT") { return "xmark.circle.fill" }
        if state.contains("READY") { return "checkmark.circle.fill" }
        if state.contains("PREPARE") { return "pencil.circle.fill" }
        return "circle"
    }

    var stateColor: Color {
        let state = appStoreState.uppercased()
        if state.contains("REJECT") { return .red }
        if state.contains("READY") { return .green }
        if state.contains("PREPARE") { return .orange }
        return .secondary
    }
}
