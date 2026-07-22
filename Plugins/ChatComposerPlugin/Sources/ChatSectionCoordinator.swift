import AppKit
import Combine
import SwiftUI
import LumiKernel

@MainActor
public final class ChatSectionCoordinator: ObservableObject {
    @Published public var draft = ""
    @Published public var rawMessageIDs: Set<UUID> = []
    @Published public var oldestVisibleMessageID: UUID?
    @Published public var inputHeight: CGFloat = 44
    @Published public var isInputFocused = false
    @Published public var inputCursorPosition = 0
    @Published public var isImageDragHovering = false
    @Published public var imageAttachments: [LumiImageAttachment] = []
    @Published public var showCommandSuggestions = false
    @Published public var showImageUnsupportedAlert = false
    @Published public private(set) var chatSectionToolbarItems: [LumiChatSectionToolbarItem] = []

    public init() {}
}
