import Foundation
import LumiCoreKit
import Testing

/// 线程安全的布尔容器，供取消回调在并发上下文里安全翻转标记。
private final class Flag: @unchecked Sendable {
    private let lock = NSLock()
    private var _value = false
    var value: Bool {
        lock.lock(); defer { lock.unlock() }
        return _value
    }
    func set() {
        lock.lock(); _value = true; lock.unlock()
    }
}

struct LumiToolExecutionContextCancellationTests {
    @Test func notCancelledByDefault() {
        let context = LumiToolExecutionContext(
            conversationID: UUID(),
            toolCallID: "tc1",
            toolName: "noop"
        )
        #expect(context.isCancelled == false)
        // 默认未取消时 checkCancellation 不应抛出
        #expect(throws: Never.self) {
            try context.checkCancellation()
        }
    }

    @Test func cancelMarksAsCancelled() {
        let context = LumiToolExecutionContext(
            conversationID: UUID(),
            toolCallID: "tc1",
            toolName: "noop"
        )
        context.cancel()
        #expect(context.isCancelled)
    }

    @Test func checkCancellationThrowsAfterCancel() {
        let context = LumiToolExecutionContext(
            conversationID: UUID(),
            toolCallID: "tc1",
            toolName: "noop"
        )
        context.cancel()
        #expect(throws: CancellationError.self) {
            try context.checkCancellation()
        }
    }

    @Test func cancelIsIdempotent() {
        let context = LumiToolExecutionContext(
            conversationID: UUID(),
            toolCallID: "tc1",
            toolName: "noop"
        )
        context.cancel()
        context.cancel() // 第二次不应崩溃
        #expect(context.isCancelled)
    }

    @Test func onCancelFiresImmediatelyIfAlreadyCancelled() {
        let context = LumiToolExecutionContext(
            conversationID: UUID(),
            toolCallID: "tc1",
            toolName: "noop"
        )
        context.cancel()

        let fired = Flag()
        let token = context.onCancel { fired.set() }
        #expect(token == nil) // 已取消，回调同步执行，不返回 token
        #expect(fired.value)
    }

    @Test func onCancelFiresWhenCancelCalled() {
        let context = LumiToolExecutionContext(
            conversationID: UUID(),
            toolCallID: "tc1",
            toolName: "noop"
        )

        let fired = Flag()
        let token = context.onCancel { fired.set() }
        #expect(token != nil)
        #expect(!fired.value)

        context.cancel()
        #expect(fired.value)
    }

    @Test func removeCancellationHandlerPreventsCallback() {
        let context = LumiToolExecutionContext(
            conversationID: UUID(),
            toolCallID: "tc1",
            toolName: "noop"
        )

        let fired = Flag()
        let token = context.onCancel { fired.set() }
        context.removeCancellationHandler(token)
        context.cancel()
        #expect(!fired.value)
    }
}

struct LumiToolExecutionContextLanguageTests {
    @Test func defaultsToEnglish() {
        let context = LumiToolExecutionContext(
            conversationID: UUID(),
            toolCallID: "tc1",
            toolName: "noop"
        )
        #expect(context.language == .english)
    }

    @Test func preservesExplicitLanguage() {
        let context = LumiToolExecutionContext(
            conversationID: UUID(),
            toolCallID: "tc1",
            toolName: "noop",
            language: .chinese
        )
        #expect(context.language == .chinese)
    }
}

struct LumiLanguagePreferenceTests {
    @Test func localeInference() {
        #expect(LumiLanguagePreference(locale: Locale(identifier: "zh-Hans")) == .chinese)
        #expect(LumiLanguagePreference(locale: Locale(identifier: "en_US")) == .english)
    }

    @Test func localizedPicksCorrectString() {
        #expect(LumiLanguagePreference.chinese.localized(en: "Hello", zh: "你好") == "你好")
        #expect(LumiLanguagePreference.english.localized(en: "Hello", zh: "你好") == "Hello")
    }
}

struct LumiToolArgumentAccessorTests {
    let args: [String: LumiJSONValue] = [
        "s": .string("hi"),
        "i": .int(42),
        "neg": .int(-7),
        "d": .double(3.14),
        "b": .bool(true),
        "arr": .array([.string("a"), .string("b")]),
    ]

    @Test func stringAccessor() {
        #expect(args.string("s") == "hi")
        #expect(args.string("missing") == nil)
    }

    @Test func intAccessorHandlesDoubleAndString() {
        #expect(args.int("i") == 42)
        #expect(args.int("neg") == -7)
        #expect(["i": .double(9.0)].int("i") == 9)
        #expect(["i": .string("15")].int("i") == 15)
    }

    @Test func doubleAccessorHandlesIntAndString() {
        #expect(args.double("d") == 3.14)
        #expect(args.double("i") == 42.0)
        #expect(["d": .string("2.5")].double("d") == 2.5)
    }

    @Test func boolAccessorHandlesIntAndString() {
        #expect(args.bool("b") == true)
        #expect(["b": .int(1)].bool("b") == true)
        #expect(["b": .int(0)].bool("b") == false)
        #expect(["b": .string("yes")].bool("b") == true)
        #expect(["b": .string("no")].bool("b") == false)
    }

    @Test func stringArrayAccessor() {
        #expect(args.stringArray("arr") == ["a", "b"])
        #expect(args.stringArray("s") == nil) // 不是数组
    }
}
