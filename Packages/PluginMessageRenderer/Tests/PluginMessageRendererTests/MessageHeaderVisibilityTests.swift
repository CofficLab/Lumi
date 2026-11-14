import Foundation
import ProviderConversation
import Testing
@testable import PluginMessageRenderer

@Suite("消息头可见性")
struct MessageHeaderVisibilityTests {
    @Test("V2 / V3 / V4 / V5 显示消息头")
    func richModesShowHeader() {
        for verbosity in [ResponseVerbosity.standard, .detailed, .zcode, .chatGPT] {
            #expect(
                MessageHeaderVisibility.isVisible(showsHeader: true, verbosity: verbosity),
                "\(verbosity.rawValue) 应当显示消息头"
            )
        }
    }

    @Test("V1 与 V6 不显示消息头")
    func briefAndStandardNoHeaderHideHeader() {
        #expect(!MessageHeaderVisibility.isVisible(showsHeader: true, verbosity: .brief))
        #expect(!MessageHeaderVisibility.isVisible(showsHeader: true, verbosity: .standardNoHeader))
    }

    @Test("调用方显式关闭时任何级别都不显示")
    func explicitFalseWins() {
        for verbosity in ResponseVerbosity.allCases {
            #expect(!MessageHeaderVisibility.isVisible(showsHeader: false, verbosity: verbosity))
        }
    }
}
