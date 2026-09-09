import ProviderDeveloperMode
import SwiftUI
import KitLocalization
import LumiUI

struct DeveloperModeToggleView: View {
    @LumiTheme private var theme
    private let provider: any DeveloperModeProviding
    @State private var isEnabled = false
    @State private var observerHandle: (any DeveloperModeProvidingObserverHandle)?

    init(provider: any DeveloperModeProviding) {
        self.provider = provider
    }

    var body: some View {
        Button {
            provider.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isEnabled ? "hammer.fill" : "hammer")
                Text(LumiPluginLocalization.string("DEV"))
            }
            .font(.appMicroEmphasized)
            .tracking(0.3)
            .foregroundStyle(isEnabled ? .white : theme.textSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                isEnabled
                    ? theme.warning
                    : theme.textSecondary.opacity(0.12),
                in: Capsule(style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .help(
            LumiPluginLocalization.string(
                isEnabled ? "Developer mode is enabled" : "Developer mode is disabled"
            )
        )
        .accessibilityLabel(LumiPluginLocalization.string("Developer mode"))
        .accessibilityValue(
            LumiPluginLocalization.string(
                isEnabled ? "Developer mode is enabled" : "Developer mode is disabled"
            )
        )
        .onAppear {
            guard observerHandle == nil else { return }
            isEnabled = provider.isEnabled
            observerHandle = provider.addObserver { event in
                guard case let .enabledChanged(value) = event else { return }
                isEnabled = value
            }
        }
        .onDisappear {
            observerHandle?.cancel()
            observerHandle = nil
        }
    }
}
