import Combine
import LumiCoreKit

@MainActor
public final class WindowChatTimelineViewModel: ObservableObject {
    @Published public var messages: [ChatMessage] = []

    public init() {}
}
