import SwiftUI

@MainActor
public final class DefaultChatSectionProviding: ChatSectionProviding, ObservableObject {
    @Published public private(set) var isVisible: Bool = true
    @Published public private(set) var isContextActive: Bool = false
    @Published public private(set) var items: [ChatSectionItem] = []
    @Published public private(set) var barItems: [ChatSectionBarItem] = []

    public init() {}

    public func addItems(_ newItems: [ChatSectionItem]) {
        var byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        for item in newItems { byID[item.id] = item }
        items = byID.values.sorted { $0.order == $1.order ? $0.id < $1.id : $0.order < $1.order }
    }

    public func removeItem(id: String) {
        items.removeAll { $0.id == id }
    }

    public func addBarItems(_ newItems: [ChatSectionBarItem]) {
        var byID = Dictionary(uniqueKeysWithValues: barItems.map { ($0.id, $0) })
        for item in newItems { byID[item.id] = item }
        barItems = byID.values.sorted { $0.order == $1.order ? $0.id < $1.id : $0.order < $1.order }
    }

    public func removeBarItem(id: String) {
        barItems.removeAll { $0.id == id }
    }

    public func setVisible(_ visible: Bool) {
        isVisible = visible
    }

    public func setContextActive(_ active: Bool) {
        isContextActive = active
    }

    public func makeChatSectionView() -> AnyView {
        AnyView(ChatSectionHostView(provider: self))
    }
}

@MainActor
private struct ChatSectionHostView: View {
    @ObservedObject var provider: DefaultChatSectionProviding

    private var stackItems: [ChatSectionItem] {
        provider.items.filter { $0.placement == .stack }
    }

    private var bottomItems: [ChatSectionItem] {
        provider.items.filter { $0.placement == .bottomFixed }
    }

    private func bars(_ placement: ChatSectionBarPlacement) -> [ChatSectionBarItem] {
        provider.barItems.filter { $0.placement == placement }
    }

    var body: some View {
        Group {
            if provider.isVisible {
                VStack(spacing: 0) {
                    if provider.isContextActive {
                        ChatBarRow(items: bars(.header), height: 40)
                        ChatToolbarRow(
                            leading: bars(.toolbarLeading),
                            trailing: bars(.toolbarTrailing)
                        )
                    }

                    ChatStackView(items: stackItems)
                        .frame(maxHeight: .infinity)

                    ChatBottomFixedView(items: bottomItems)

                    ChatActionBarView(
                        leading: bars(.actionLeading),
                        trailing: bars(.actionTrailing)
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

@MainActor
private struct ChatStackView: View {
    let items: [ChatSectionItem]

    var body: some View {
        let hasPrimary = items.contains { $0.fillsRemainingHeight }
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let isPrimary = item.fillsRemainingHeight || (!hasPrimary && index == 0)
                item.makeView()
                    .frame(maxWidth: .infinity, alignment: .top)
                    .frame(maxHeight: isPrimary ? .infinity : nil, alignment: .top)
                    .layoutPriority(isPrimary ? 1 : 0)

                if index < items.count - 1, item.showsTrailingDivider {
                    Divider()
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

@MainActor
private struct ChatBottomFixedView: View {
    let items: [ChatSectionItem]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                item.makeView()
                    .frame(maxWidth: .infinity, alignment: .bottom)

                if index < items.count - 1, item.showsTrailingDivider {
                    Divider()
                }
            }
        }
    }
}

@MainActor
private struct ChatBarRow: View {
    let items: [ChatSectionBarItem]
    let height: CGFloat

    var body: some View {
        HStack(spacing: 8) {
            ForEach(items) { $0.makeView() }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .bottom) { Divider() }
    }
}

@MainActor
private struct ChatToolbarRow: View {
    let leading: [ChatSectionBarItem]
    let trailing: [ChatSectionBarItem]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(leading) { $0.makeView() }
            Spacer(minLength: 0)
            ForEach(trailing) { $0.makeView() }
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .bottom) { Divider() }
    }
}

@MainActor
private struct ChatActionBarView: View {
    let leading: [ChatSectionBarItem]
    let trailing: [ChatSectionBarItem]

    var body: some View {
        Group {
            if !leading.isEmpty || !trailing.isEmpty {
                HStack(spacing: 8) {
                    ForEach(leading) { $0.makeView() }
                    Spacer(minLength: 0)
                    ForEach(trailing) { $0.makeView() }
                }
                .padding(.horizontal, 10)
                .frame(height: 36)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .top) { Divider() }
            }
        }
    }
}
