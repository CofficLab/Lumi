import LumiUI
import LumiCoreKit
import SwiftUI
import UniformTypeIdentifiers

/// 包裹右侧栏，提供文件拖放入口。
public struct ChatAttachmentDropRootView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    @EnvironmentObject private var conversationVM: WindowConversationVM

    public let content: AnyView

    @State private var isImageDragHovering = false

    public init(content: AnyView) {
        self.content = content
    }

    private var canChat: Bool {
        conversationVM.canAttachToCurrentConversation
    }

    public var body: some View {
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
                delegate: ChatAttachmentRootDropDelegate(
                    isImageHintVisible: $isImageDragHovering,
                    canAcceptDrop: { canChat },
                    shouldShowImageHint: { Self.dropInfoSuggestsChatImage($0) },
                    onPerform: { acceptChatFileDropFromProviders($0) }
                )
            )
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

                Text(LumiPluginLocalization.string("Release to add image to chat", bundle: .module))
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

    private func acceptChatFileDropFromProviders(_ providers: [NSItemProvider]) -> Bool {
        guard canChat, !providers.isEmpty else { return false }

        var didAcceptProvider = false
        for provider in providers {
            if provider.canLoadObject(ofClass: URL.self) {
                didAcceptProvider = true
                _ = provider.loadObject(ofClass: URL.self) { item, _ in
                    guard let url = item else { return }
                    Task { @MainActor in
                        handleFileDrop(fileURL: url)
                    }
                }
                continue
            }

            if provider.canLoadObject(ofClass: String.self) {
                didAcceptProvider = true
                _ = provider.loadObject(ofClass: String.self) { item, _ in
                    guard let path = item else { return }
                    let urls = ChatAttachmentDropRules.fileURLs(fromDroppedString: path)
                    guard !urls.isEmpty else { return }
                    Task { @MainActor in
                        for url in urls {
                            handleFileDrop(fileURL: url)
                        }
                    }
                }
            }
        }

        return didAcceptProvider
    }

    private func handleFileDrop(fileURL: URL) {
        if ChatAttachmentDropRules.isChatImageFileURL(fileURL) {
            conversationVM.handleImageUpload(url: fileURL)
        } else {
            conversationVM.appendDraftText(fileURL.path)
        }
    }

    private static func dropInfoSuggestsChatImage(_ info: DropInfo) -> Bool {
        let imageUTTypes: [UTType] = [.image, .jpeg, .png, .gif, .webP, .heic, .tiff, .bmp]
        if imageUTTypes.contains(where: { !info.itemProviders(for: [$0]).isEmpty }) {
            return true
        }
        for provider in info.itemProviders(for: [.item]) {
            if let suggested = provider.suggestedName {
                let ext = (suggested as NSString).pathExtension.lowercased()
                if ChatAttachmentDropRules.imagePathExtensions.contains(ext) {
                    return true
                }
            }
            for id in provider.registeredTypeIdentifiers {
                if let ut = UTType(id), ut.conforms(to: .image) {
                    return true
                }
            }
        }
        return false
    }
}

private struct ChatAttachmentRootDropDelegate: DropDelegate {
    @Binding var isImageHintVisible: Bool
    public var canAcceptDrop: () -> Bool
    public var shouldShowImageHint: (DropInfo) -> Bool
    public var onPerform: ([NSItemProvider]) -> Bool

    public func validateDrop(info: DropInfo) -> Bool {
        guard canAcceptDrop() else { return false }
        return !info.itemProviders(for: [UTType.fileURL]).isEmpty
            || !info.itemProviders(for: [UTType.utf8PlainText]).isEmpty
    }

    public func dropEntered(info: DropInfo) {
        updateHint(info)
    }

    public func dropUpdated(info: DropInfo) -> DropProposal? {
        updateHint(info)
        return validateDrop(info: info) ? DropProposal(operation: .copy) : DropProposal(operation: .forbidden)
    }

    public func dropExited(info: DropInfo) {
        isImageHintVisible = false
    }

    public func performDrop(info: DropInfo) -> Bool {
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
