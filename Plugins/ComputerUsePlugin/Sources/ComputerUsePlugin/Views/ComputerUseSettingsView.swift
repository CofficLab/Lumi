import AppKit
import SwiftUI

@MainActor
struct ComputerUseSettingsView: View {
    @State private var applications: [RunningApplicationItem] = []
    @State private var screenRecordingAllowed = false
    @State private var accessibilityAllowed = false
    @State private var revision = 0

    var body: some View {
        Form {
            Section("System Permissions") {
                permissionRow(
                    title: "Screen Recording",
                    detail: "Allows Lumi to capture the selected application window.",
                    granted: screenRecordingAllowed,
                    request: {
                        ComputerUsePermissionService.requestScreenRecordingPermission()
                        refresh()
                    }
                )
                permissionRow(
                    title: "Accessibility",
                    detail: "Allows Lumi to click, type, scroll, and navigate.",
                    granted: accessibilityAllowed,
                    request: {
                        ComputerUsePermissionService.requestAccessibilityPermission()
                        refresh()
                    }
                )
            }

            Section("Allowed Applications") {
                if applications.isEmpty {
                    Text("Open an application to add it to the Computer Use allow list.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(applications) { application in
                        Toggle(isOn: allowedBinding(for: application)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(application.name)
                                Text(application.bundleIdentifier)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section {
                Text("Computer Use captures only the selected window. Password fields are blocked, stale screenshot coordinates are rejected, and state-changing batches require approval in Build mode.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .id(revision)
        .onAppear(perform: refresh)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refresh()
        }
    }

    @ViewBuilder
    private func permissionRow(
        title: String,
        detail: String,
        granted: Bool,
        request: @escaping () -> Void
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Label(granted ? "Granted" : "Required", systemImage: granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(granted ? .green : .orange)
            if !granted {
                Button("Grant Access", action: request)
            }
        }
    }

    private func allowedBinding(for application: RunningApplicationItem) -> Binding<Bool> {
        Binding(
            get: {
                _ = revision
                return ComputerUseAuthorizationStore.shared.isAllowed(application.bundleIdentifier)
            },
            set: { allowed in
                ComputerUseAuthorizationStore.shared.setAllowed(
                    allowed,
                    bundleIdentifier: application.bundleIdentifier
                )
                revision += 1
            }
        )
    }

    private func refresh() {
        screenRecordingAllowed = ComputerUsePermissionService.hasScreenRecordingPermission
        accessibilityAllowed = ComputerUsePermissionService.hasAccessibilityPermission
        let ownPID = ProcessInfo.processInfo.processIdentifier
        var applicationsByID = NSWorkspace.shared.runningApplications.compactMap { application in
            guard application.processIdentifier != ownPID,
                  application.activationPolicy == .regular,
                  let bundleIdentifier = application.bundleIdentifier,
                  let name = application.localizedName
            else { return nil }
            return RunningApplicationItem(bundleIdentifier: bundleIdentifier, name: name)
        }
        .reduce(into: [String: RunningApplicationItem]()) { result, item in
            result[item.bundleIdentifier] = item
        }
        for bundleIdentifier in ComputerUseAuthorizationStore.shared.allowedBundleIdentifiers()
        where applicationsByID[bundleIdentifier] == nil {
            let applicationURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
            let bundle = applicationURL.flatMap(Bundle.init(url:))
            let name = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? bundleIdentifier
            applicationsByID[bundleIdentifier] = RunningApplicationItem(
                bundleIdentifier: bundleIdentifier,
                name: name
            )
        }
        applications = applicationsByID.values
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        revision += 1
    }
}

private struct RunningApplicationItem: Identifiable, Equatable {
    var id: String { bundleIdentifier }
    let bundleIdentifier: String
    let name: String
}
