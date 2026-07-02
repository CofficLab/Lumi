public enum LumiChatMessageRole: String, Codable, Sendable, CaseIterable {
    case system
    case user
    case assistant
    case tool
    case error
    case status
}
