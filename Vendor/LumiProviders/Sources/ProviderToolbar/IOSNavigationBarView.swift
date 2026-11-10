#if os(iOS)
import Combine
import SwiftUI

/// Shared iOS navigation header for toolbar contributions.
///
/// The host supplies its title and back action; leading, principal, and trailing
/// plugin contributions are laid out consistently across apps.
@MainActor
public struct IOSNavigationBarView: View {
    private let title: String
    private let showsBackButton: Bool
    private let backButtonLabel: String
    private let backButtonAccessibilityIdentifier: String?
    private let onBack: () -> Void

    @StateObject private var providerAdapter: IOSNavigationBarProviderAdapter

    public init(
        title: String,
        showsBackButton: Bool = false,
        backButtonLabel: String = "Back",
        backButtonAccessibilityIdentifier: String? = nil,
        onBack: @escaping () -> Void = {},
        provider: any IOSNavigationBarProviding
    ) {
        self.title = title
        self.showsBackButton = showsBackButton
        self.backButtonLabel = backButtonLabel
        self.backButtonAccessibilityIdentifier = backButtonAccessibilityIdentifier
        self.onBack = onBack
        _providerAdapter = StateObject(
            wrappedValue: IOSNavigationBarProviderAdapter(provider: provider)
        )
    }

    private var leadingItems: [IOSNavigationBarItem] {
        providerAdapter.visibleNavigationBarItems.filter { $0.placement == .leading }
    }

    private var principalItems: [IOSNavigationBarItem] {
        providerAdapter.visibleNavigationBarItems.filter { $0.placement == .principal }
    }

    private var trailingItems: [IOSNavigationBarItem] {
        providerAdapter.visibleNavigationBarItems.filter { $0.placement == .trailing }
    }

    public var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                if showsBackButton {
                    backButton
                }

                ForEach(leadingItems) { item in
                    item.makeView()
                        .accessibilityLabel(item.title)
                }
            }

            Spacer(minLength: 0)

            if principalItems.isEmpty {
                Text(title)
                    .font(showsBackButton ? .headline : .largeTitle)
                    .fontWeight(showsBackButton ? .semibold : .bold)
                    .lineLimit(1)
            } else {
                HStack(spacing: 8) {
                    ForEach(principalItems) { item in
                        item.makeView()
                            .accessibilityLabel(item.title)
                    }
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                ForEach(trailingItems) { item in
                    item.makeView()
                        .accessibilityLabel(item.title)
                }
            }
            .frame(minWidth: showsBackButton ? 40 : 0, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .frame(height: showsBackButton ? 48 : 64)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    @ViewBuilder
    private var backButton: some View {
        let button = Button(action: onBack) {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 32, height: 32)
        }
        .accessibilityLabel(backButtonLabel)

        if let backButtonAccessibilityIdentifier {
            button.accessibilityIdentifier(backButtonAccessibilityIdentifier)
        } else {
            button
        }
    }
}

@MainActor
private final class IOSNavigationBarProviderAdapter: ObservableObject {
    private let provider: any IOSNavigationBarProviding
    private var observation: AnyCancellable?

    init(provider: any IOSNavigationBarProviding) {
        self.provider = provider
        observation = provider.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    var visibleNavigationBarItems: [IOSNavigationBarItem] {
        provider.visibleNavigationBarItems
    }
}
#endif
