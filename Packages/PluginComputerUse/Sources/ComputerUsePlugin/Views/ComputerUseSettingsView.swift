import AppKit
import LumiUI
import SwiftUI

@MainActor
struct ComputerUseSettingsView: View {
    @LumiTheme private var theme
    @State private var applications: [RunningApplicationItem] = []
    @State private var selectedBundleIdentifier: String?
    @State private var screenRecordingAllowed = false
    @State private var accessibilityAllowed = false
    @State private var revision = 0

    private var selectedApplication: RunningApplicationItem? {
        guard let selectedBundleIdentifier else { return nil }
        return applications.first { $0.bundleIdentifier == selectedBundleIdentifier }
    }

    var body: some View {
        PluginSettingsScaffold(title: LumiPluginLocalization.string("Computer Use", bundle: .module), subtitle: LumiPluginLocalization.string("Control which applications Lumi can observe and interact with.", bundle: .module), showHeader: false, scrollsContent: false) {
            VStack(alignment: .leading, spacing: 14) {
                permissionsSection
                applicationsSection
                Text(LumiPluginLocalization.string("Computer Use captures only the selected window. Password fields are blocked, stale screenshot coordinates are rejected, and state-changing batches require approval in Build mode.", bundle: .module))
                    .font(.callout).foregroundStyle(theme.textSecondary).padding(.horizontal, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .id(revision)
        .onAppear(perform: refresh)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in refresh() }
    }

    private var permissionsSection: some View {
        AppSettingsSection(title: LumiPluginLocalization.string("System Permissions", bundle: .module), subtitle: LumiPluginLocalization.string("These permissions are required before Computer Use can operate.", bundle: .module), spacing: 8) {
            HStack(spacing: 8) {
                permissionCard(title: LumiPluginLocalization.string("Screen Recording", bundle: .module), detail: LumiPluginLocalization.string("Allows Lumi to capture the selected application window.", bundle: .module), granted: screenRecordingAllowed, icon: "rectangle.dashed.and.paperclip") {
                    ComputerUsePermissionService.requestScreenRecordingPermission(); refresh()
                }
                permissionCard(title: LumiPluginLocalization.string("Accessibility", bundle: .module), detail: LumiPluginLocalization.string("Allows Lumi to click, type, scroll, and navigate.", bundle: .module), granted: accessibilityAllowed, icon: "accessibility") {
                    ComputerUsePermissionService.requestAccessibilityPermission(); refresh()
                }
            }
        }
    }

    private func permissionCard(title: String, detail: String, granted: Bool, icon: String, request: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(granted ? theme.success : theme.warning).frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.appCaptionEmphasized)
                Text(detail).font(.appMicro).foregroundStyle(theme.textSecondary)
            }
            Spacer(minLength: 4)
            if granted { Image(systemName: "checkmark.circle.fill").foregroundStyle(theme.success) }
            else { AppButton(LumiPluginLocalization.string("Grant Access", bundle: .module), size: .small, action: request) }
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(theme.divider, lineWidth: 0.5) }
    }

    private var applicationsSection: some View {
        AppSettingsSection(title: LumiPluginLocalization.string("Allowed Applications", bundle: .module), subtitle: LumiPluginLocalization.string("Select an application to manage its Computer Use access.", bundle: .module), spacing: 0) {
            HStack(spacing: 0) {
                applicationList.frame(width: 300)
                AppDivider(.vertical)
                applicationDetail.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(minHeight: 300, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(theme.divider, lineWidth: 1) }
        }
    }

    private var applicationList: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(applications) { application in
                    AppListRow(isSelected: selectedBundleIdentifier == application.bundleIdentifier, action: { selectedBundleIdentifier = application.bundleIdentifier }) {
                        HStack(spacing: 10) {
                            Image(nsImage: application.icon).resizable().frame(width: 28, height: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(application.name).font(.appCaptionEmphasized).lineLimit(1)
                                Text(application.bundleIdentifier).font(.appMicro).foregroundStyle(theme.textSecondary).lineLimit(1)
                            }
                        }
                    }
                }
                if applications.isEmpty { AppEmptyState(icon: "app.dashed", title: LumiPluginLocalization.string("No Applications", bundle: .module)).padding(.vertical, 30) }
            }.padding(8)
        }.appSurface(style: .panel, cornerRadius: 0)
    }

    @ViewBuilder
    private var applicationDetail: some View {
        if let application = selectedApplication {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 14) {
                        Image(nsImage: application.icon).resizable().frame(width: 56, height: 56)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(application.name).font(.title2.weight(.semibold)).foregroundStyle(theme.textPrimary)
                            Text(application.bundleIdentifier).font(.appCaption).foregroundStyle(theme.textSecondary)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        let isAllowed = ComputerUseAuthorizationStore.shared.isAllowed(application.bundleIdentifier)
                        AppButton(isAllowed ? LumiPluginLocalization.string("Not Allowed", bundle: .module) : LumiPluginLocalization.string("Allow", bundle: .module), systemImage: isAllowed ? "xmark" : "checkmark", size: .small) {
                            ComputerUseAuthorizationStore.shared.setAllowed(!isAllowed, bundleIdentifier: application.bundleIdentifier)
                            revision += 1
                        }.fixedSize()
                    }
                    AppDivider()
                    AppSettingRow(title: LumiPluginLocalization.string("Computer Use Access", bundle: .module), description: ComputerUseAuthorizationStore.shared.isAllowed(application.bundleIdentifier) ? LumiPluginLocalization.string("Lumi can observe and interact with this application.", bundle: .module) : LumiPluginLocalization.string("Lumi must be allowed before it can interact with this application.", bundle: .module), icon: "hand.raised") { EmptyView() }
                }.padding(22)
            }
        } else {
            AppEmptyState(icon: "app", title: LumiPluginLocalization.string("Select an Application", bundle: .module)).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func refresh() {
        screenRecordingAllowed = ComputerUsePermissionService.hasScreenRecordingPermission
        accessibilityAllowed = ComputerUsePermissionService.hasAccessibilityPermission
        let ownPID = ProcessInfo.processInfo.processIdentifier
        var applicationsByID = NSWorkspace.shared.runningApplications.compactMap { application in
            guard application.processIdentifier != ownPID, application.activationPolicy == .regular, let bundleIdentifier = application.bundleIdentifier, let name = application.localizedName else { return nil }
            return RunningApplicationItem(bundleIdentifier: bundleIdentifier, name: name, icon: application.icon ?? NSImage(systemSymbolName: "app", accessibilityDescription: nil)!)
        }.reduce(into: [String: RunningApplicationItem]()) { $0[$1.bundleIdentifier] = $1 }
        for bundleIdentifier in ComputerUseAuthorizationStore.shared.allowedBundleIdentifiers() where applicationsByID[bundleIdentifier] == nil {
            let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
            let bundle = url.flatMap(Bundle.init(url:))
            let name = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String ?? bundleIdentifier
            applicationsByID[bundleIdentifier] = RunningApplicationItem(bundleIdentifier: bundleIdentifier, name: name, icon: url.map { NSWorkspace.shared.icon(forFile: $0.path) } ?? NSImage(systemSymbolName: "app", accessibilityDescription: nil)!)
        }
        applications = applicationsByID.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        if selectedBundleIdentifier == nil || !applications.contains(where: { $0.bundleIdentifier == selectedBundleIdentifier }) { selectedBundleIdentifier = applications.first?.bundleIdentifier }
        revision += 1
    }
}

private struct RunningApplicationItem: Identifiable, Equatable {
    var id: String { bundleIdentifier }
    let bundleIdentifier: String
    let name: String
    let icon: NSImage
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.bundleIdentifier == rhs.bundleIdentifier }
}
