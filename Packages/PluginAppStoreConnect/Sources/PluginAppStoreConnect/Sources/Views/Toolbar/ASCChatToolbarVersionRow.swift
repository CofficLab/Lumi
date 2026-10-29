import LumiUI
import SwiftUI

/// Chat Toolbar 弹层中的版本行：版本号 + 状态标签。
struct ASCChatToolbarVersionRow: View {
    let version: AppStoreVersion

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: Self.icon(for: version))
                .font(.caption2)
                .foregroundStyle(Self.color(for: version))
                .frame(width: 14)

            Text(version.versionString)
                .font(.callout)
                .lineLimit(1)

            Spacer(minLength: 0)

            Text(Self.stateLabel(for: version))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
    }

    // MARK: - Display Rules

    private static func icon(for version: AppStoreVersion) -> String {
        let state = version.appStoreState.uppercased()
        if state.contains("REJECT") { return "xmark.circle.fill" }
        if state.contains("READY") { return "checkmark.circle.fill" }
        if state.contains("PREPARE") { return "pencil.circle.fill" }
        return "circle"
    }

    private static func color(for version: AppStoreVersion) -> Color {
        let state = version.appStoreState.uppercased()
        if state.contains("REJECT") { return .red }
        if state.contains("READY") { return .green }
        if state.contains("PREPARE") { return .orange }
        return .secondary
    }

    private static func stateLabel(for version: AppStoreVersion) -> String {
        let state = version.appStoreState.uppercased()
        if state == "PENDING_DEVELOPER_RELEASE" {
            return AppStoreConnectLocalization.string("Pending Developer Release")
        }
        if state.contains("READY") { return AppStoreConnectLocalization.string("Ready") }
        if state.contains("PREPARE") { return AppStoreConnectLocalization.string("Prepare") }
        if state.contains("REJECT") { return AppStoreConnectLocalization.string("Rejected") }
        if state.contains("REVIEW") { return AppStoreConnectLocalization.string("In Review") }
        if state.contains("REPLACED") { return AppStoreConnectLocalization.string("Replaced") }
        return version.localizedAppStoreStateLabel
    }
}

#Preview {
    VStack(spacing: 0) {
        ASCChatToolbarVersionRow(
            version: AppStoreVersion(
                id: "v1",
                platform: "IOS",
                versionString: "1.2.0",
                appStoreState: "READY_FOR_SALE",
                appVersionState: "RELEASED",
                createdDate: nil
            )
        )
        ASCChatToolbarVersionRow(
            version: AppStoreVersion(
                id: "v2",
                platform: "IOS",
                versionString: "1.3.0",
                appStoreState: "PREPARE_FOR_SUBMISSION",
                appVersionState: "PREPARE_FOR_SUBMISSION",
                createdDate: nil
            )
        )
        ASCChatToolbarVersionRow(
            version: AppStoreVersion(
                id: "v3",
                platform: "IOS",
                versionString: "1.4.0",
                appStoreState: "REJECTED",
                appVersionState: "REJECTED",
                createdDate: nil
            )
        )
    }
    .frame(width: 320)
    .padding(.vertical, 8)
}
