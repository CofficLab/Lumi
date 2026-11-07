import LumiUI
import SwiftUI

/// Renders the settings shell for any `SettingViewProviding` implementation.
@MainActor
public func makeSettingView<Provider: SettingViewProviding>(
    provider: Provider
) -> AnyView {
    AnyView(SettingView(provider: provider))
}

@MainActor
struct SettingView<Provider: SettingViewProviding>: View {
    let provider: Provider
    @State private var observationRevision = 0
    @State private var observerHandle: (any SettingViewObserverHandle)?
    @LumiTheme private var theme

    init(provider: Provider) {
        self.provider = provider
    }

    @ViewBuilder
    var body: some View {
#if os(iOS)
        IOSSettingsNavigationView(provider: provider)
#else
        AppSettingsSidebarShell { sidebar } detail: { detail }
            .frame(minWidth: 960, minHeight: 520)
            .background(theme.background)
            .appThemedAppearance()
#if canImport(AppKit)
            .background { ThemeWindowAppearanceBridge() }
#endif
            .ignoresSafeArea()
            .onAppear(perform: selectFirstEntryIfNeeded)
            .onAppear(perform: startObserving)
            .onDisappear(perform: stopObserving)
#endif
    }

#if !os(iOS)
    private var sidebar: some View {
        AppSettingsSidebarContainer(width: 220) {
            VStack(alignment: .leading, spacing: 10) {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(provider.entries) { entry in
                            AppSettingsSidebarItem(
                                title: entry.title,
                                systemImage: entry.systemImage,
                                isSelected: provider.selectedEntryID == entry.id
                            ) {
                                provider.selectEntry(id: entry.id)
                            }
                        }
                    }
                    .padding(.leading)
                }
                Spacer()
            }
        }
    }

    private var detail: some View {
        AppSettingsDetailPane {
            if let entry = provider.entries.first(where: { $0.id == provider.selectedEntryID }) {
                entry.makeDetailView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                AppEmptyState(
                    icon: "gearshape",
                    title: LumiUILocalization.string("Select a setting"),
                    description: LumiUILocalization.string("Choose a setting from the sidebar")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
#endif

    private func selectFirstEntryIfNeeded() {
        guard provider.selectedEntryID == nil,
              let firstEntry = provider.entries.first else { return }
        provider.selectEntry(id: firstEntry.id)
    }

    private func startObserving() {
        guard observerHandle == nil else { return }
        observerHandle = provider.addSettingViewObserver { _ in
            observationRevision += 1
        }
    }

    private func stopObserving() {
        observerHandle?.cancel()
        observerHandle = nil
    }
}
