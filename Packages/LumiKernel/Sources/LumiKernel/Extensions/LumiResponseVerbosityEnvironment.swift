import SwiftUI

private struct LumiResponseVerbosityKey: EnvironmentKey {
    static let defaultValue: LumiResponseVerbosity = .defaultVerbosity
}

extension EnvironmentValues {
    public var lumiResponseVerbosity: LumiResponseVerbosity {
        get { self[LumiResponseVerbosityKey.self] }
        set { self[LumiResponseVerbosityKey.self] = newValue }
    }
}
