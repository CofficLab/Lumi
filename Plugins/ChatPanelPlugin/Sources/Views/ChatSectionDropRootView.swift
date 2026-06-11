import LumiCoreKit
import LumiUI
import SwiftUI
import UniformTypeIdentifiers

struct ChatSectionDropRootView: View {
    @LumiTheme private var theme
    @ObservedObject var coordinator: ChatSectionCoordinator
    let content: AnyView

    @State private var isImageDragHovering = false

    var body: some View {
        content
            .contentShape(Rectangle())
            .overlay {
                if canChat, isImageDragHovering {
                    imageDropHoverOverlay
                }
            }
            .animation(.easeInOut(duration: 0.12), value: isImageDragHovering)
            .onDrop(
                of: [UTType.fileURL, UTType.utf8PlainText],
                delegate: ChatSectionRootDropDelegate(
                    isImageHintVisible: $isImageDragHovering,
                    canAcceptDrop: { canChat },
                    shouldShowImageHint: { dropInfoSuggestsChatImage($0) },
                    onPerform: { acceptFileDropFromProviders($0) }
                )
            )
    }

    private var canChat: Bool {
        coordinator.selectedConversationID != nil || !coordinator.chatService.conversations.isEmpty
    }

    private var imageDropHoverOverlay: some View {
        ZStack(alignment: .topTrailing) {
            Rectangle()
                .fill(.ultraThinMaterial)
                .appSurface(
                    style: .glass,
                    cornerRadius: 8,
                    borderColor: theme.textSecondary.opacity(0.65),
                    lineWidth: 2
                )
                .allowsHitTesting(false)

            VStack(spacing: 8) {
                Image(systemName: "photo.badge.plus")
                    .font(.appTitle)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(theme.textSecondary)

                Text("Release to add image to chat", bundle: .module)
                    .font(.appBodyEmphasized)
                    .foregroundStyle(theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
            .allowsHitTesting(false)

            Button {
                isImageDragHovering = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.appBody)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(theme.textSecondary)
            }
            .buttonStyle(.plain)
            .padding(8)
        }
        .transition(.opacity)
    }

    private func acceptFileDropFromProviders(_ providers: [NSItemProvider]) -> Bool {
        guard canChat, !providers.isEmpty else { return false }

        var didAcceptProvider = false
        for provider in providers {
            if provider.canLoadObject(ofClass: URL.self) {
                didAcceptProvider = true
                _ = provider.loadObject(ofClass: URL.self) { item, _ in
                    guard let url = item else { return }
                    Task { @MainActor in
                        coordinator.handleFileDrop(url)
                    }
                }
                continue
            }

            if provider.canLoadObject(ofClass: String.self) {
                didAcceptProvider = true
                _ = provider.loadObject(ofClass: String.self) { item, _ in
                    guard let path = item else { return }
                    let url = URL(fileURLWithPath: path)
                    Task { @MainActor in
                        coordinator.handleFileDrop(url)
                    }
                }
            }
        }

        return didAcceptProvider
    }

    private func dropInfoSuggestsChatImage(_ info: DropInfo) -> Bool {
        let imageUTTypes: [UTType] = [.image, .jpeg, .png, .gif, .webP, .heic, .tiff, .bmp]
        if imageUTTypes.contains(where: { !info.itemProviders(for: [$0]).isEmpty }) {
            return true
        }
        for provider in info.itemProviders(for: [.item]) {
            if let suggested = provider.suggestedName {
                let ext = (suggested as NSString).pathExtension.lowercased()
                if ["png", "jpg", "jpeg", "gif", "webp", "heic", "tiff", "bmp"].contains(ext) {
                    return true
                }
            }
        }
        return false
    }
}

private struct ChatSectionRootDropDelegate: DropDelegate {
    @Binding var isImageHintVisible: Bool
    var canAcceptDrop: () -> Bool
    var shouldShowImageHint: (DropInfo) -> Bool
    var onPerform: ([NSItemProvider]) -> Bool

    func validateDrop(info: DropInfo) -> Bool {
        guard canAcceptDrop() else { return false }
        return !info.itemProviders(for: [UTType.fileURL]).isEmpty
            || !info.itemProviders(for: [UTType.utf8PlainText]).isEmpty
    }

    func dropEntered(info: DropInfo) {
        updateHint(info)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        updateHint(info)
        return validateDrop(info: info) ? DropProposal(operation: .copy) : DropProposal(operation: .forbidden)
    }

    func dropExited(info: DropInfo) {
        isImageHintVisible = false
    }

    func performDrop(info: DropInfo) -> Bool {
        isImageHintVisible = false
        let providers = info.itemProviders(for: [UTType.fileURL, UTType.utf8PlainText])
        guard !providers.isEmpty else { return false }
        return onPerform(providers)
    }

    private func updateHint(_ info: DropInfo) {
        guard validateDrop(info: info) else {
            isImageHintVisible = false
            return
        }
        isImageHintVisible = shouldShowImageHint(info)
    }
}
