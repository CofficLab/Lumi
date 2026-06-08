public enum LumiPluginPolicy: String, Sendable, Codable, CaseIterable {
    case alwaysOn
    case optOut
    case optIn
    case disabled

    public var shouldRegister: Bool {
        self != .disabled
    }

    public var isConfigurable: Bool {
        switch self {
        case .optOut, .optIn:
            true
        case .alwaysOn, .disabled:
            false
        }
    }

    public var enabledByDefault: Bool {
        switch self {
        case .alwaysOn, .optOut:
            true
        case .optIn, .disabled:
            false
        }
    }
}
