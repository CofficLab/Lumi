import Foundation

@MainActor
public enum ChatInputRuntime {
    public static var submitText: (String) async -> Void = { _ in }
    public static var canChatProvider: () -> Bool = { true }

    public static var canChat: Bool {
        canChatProvider()
    }
}
