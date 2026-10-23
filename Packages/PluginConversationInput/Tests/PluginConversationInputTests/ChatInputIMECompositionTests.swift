import AppKit
import Combine
import ProviderConversation
import ProviderConversationInput
import ProviderConversationInputBlock
import ProviderMessage
import ProviderMessageSender
import SwiftUI
import Testing
@testable import PluginConversationInput

/// 中文输入法（IME）组合态下的输入响应性。
///
/// ## 这组测试要回答什么
///
/// 用户反馈「输入中文时不跟手」。这类反馈有两个可能的来源，二者的修法完全不同：
///
/// 1. **应用侧**：每个按键都把 SwiftUI 视图树拖进一次失效广播，输入框与附件
///    预览整段重建，主线程被占满 → 表现为「按下去半天才出字」。
/// 2. **环境侧**：机器 CPU 被别的进程占满，连 AppKit 自己的排版都变慢 →
///    表现为「整体都慢」，与输入框无关。
///
/// 区分办法是**把两段耗时分开测**：
///
/// - `appSide` = 我们自己的处理（`Coordinator.textDidChange` 及其下游）；
/// - `total` = 一次按键的完整耗时（含 AppKit 的组合态排版）。
///
/// 若 `appSide` 稳定在零附近而 `total` 明显偏高，症结在环境；
/// 反之则是应用侧有每键必付的开销。
///
/// ## 判定口径
///
/// - **确定性判据**（不依赖机器负载）：组合态期间不得产生任何 SwiftUI 可见的
///   状态写入。这条一旦不成立，每个按键都会重算视图树，必然不跟手。
/// - **性能判据**（依赖机器负载）：应用侧单次按键耗时必须落在帧预算内。
///   预算取得宽松，避免在高负载机器上误报；实测数值会打印出来供人工判断。
@MainActor
@Suite("中文 IME 输入响应性")
struct ChatInputIMECompositionTests {

    @Test("IME 组合态期间不产生任何 SwiftUI 状态写入")
    func compositionPhaseDoesNotWriteSwiftUIState() {
        let harness = IMETypingHarness()
        defer { harness.tearDown() }

        // 一次真实的中文输入：拼音逐字推进，组合态一直没有上屏。
        for marked in ["n", "ni", "nih", "niha", "nihao"] {
            harness.typeMarked(marked)
        }

        #expect(
            harness.counter.textWrites == 0,
            "组合态期间写了 \(harness.counter.textWrites) 次文本绑定；拼音一旦进入草稿，用户就会看到候选词被当成正文"
        )
        #expect(
            harness.counter.heightWrites == 0,
            "组合态期间写了 \(harness.counter.heightWrites) 次高度绑定；高度一变，底部固定区会把整条消息列表重新排一遍"
        )
        #expect(
            harness.counter.cursorWrites == 0,
            "组合态期间写了 \(harness.counter.cursorWrites) 次光标绑定；光标回写会触发选区重设，输入过程中字符可能被吃掉"
        )
        #expect(
            harness.counter.blockReports == 0,
            "组合态期间上报了 \(harness.counter.blockReports) 次折叠块区间"
        )
        #expect(
            harness.counter.invalidations == 0,
            "组合态期间触发了 \(harness.counter.invalidations) 次 SwiftUI 失效广播；每次广播都会重算输入框与附件预览的视图树"
        )
        #expect(harness.viewModel.text.isEmpty, "组合态期间草稿不应被写入")
    }

    @Test("上屏后只发布一次已提交的汉字")
    func commitPublishesCommittedTextExactlyOnce() {
        let harness = IMETypingHarness()
        defer { harness.tearDown() }

        for marked in ["n", "ni", "nih", "niha", "nihao"] {
            harness.typeMarked(marked)
        }
        harness.commit("你好")

        #expect(
            harness.viewModel.text == "你好",
            "上屏后草稿应为「你好」，实际为「\(harness.viewModel.text)」"
        )
        #expect(
            harness.counter.textWrites == 1,
            "一次上屏引发了 \(harness.counter.textWrites) 次文本绑定写入；多写几次会让发送按钮与输入框不同步"
        )
        #expect(
            harness.counter.invalidations <= 3,
            "一次上屏引发了 \(harness.counter.invalidations) 次失效广播，应收敛到常数级"
        )
    }

    @Test("单次按键的应用侧开销落在帧预算内")
    func perKeystrokeAppCostFitsFrameBudget() {
        let harness = IMETypingHarness()
        defer { harness.tearDown() }

        for marked in ["n", "ni", "nih", "niha", "nihao", "ni'hao", "ni'hao shi", "ni'hao shi jie"] {
            harness.typeMarked(marked)
        }

        harness.printReport()

        let worstAppCost = harness.appSideCosts.max() ?? 0
        #expect(
            worstAppCost <= 8,
            """
            应用侧单次按键最坏耗时 \(String(format: "%.3f", worstAppCost))ms，超出 8ms 预算。这一段是纯内存工作，不该随机器负载大幅波动；超出说明每次按键都在做不必要的事（布局测量、全量状态重写等）。
            """
        )
    }
}

// MARK: - 测试夹具

/// 一次中文输入的完整生产链路。
///
/// 刻意接上真实的能力层与观察者（`DefaultConversationInputProvider` →
/// `ConversationInputObserver` → `ConversationInputViewModel`），而不是只测
/// 编辑器：逐键开销的大头往往在「编辑器上报 → 状态层回灌」这一段，
/// 只测编辑器会漏掉它。
@MainActor
private final class IMETypingHarness {
    let viewModel: ConversationInputViewModel
    let counter = WriteCounter()
    let costs = CostRecorder()
    let textView: EditorTextView

    /// 应用侧单次按键耗时（毫秒）。只统计我们自己的处理。
    var appSideCosts: [TimeInterval] { costs.appSide }
    /// 单次按键的完整耗时（毫秒），含 AppKit 的组合态排版。
    var totalCosts: [TimeInterval] { costs.total }

    private let coordinator: ChatInputEditorView.Coordinator
    private let measuringDelegate: MeasuringTextViewDelegate
    private let scrollView: NSScrollView
    private let observer: ConversationInputObserver
    private var cancellables: Set<AnyCancellable> = []

    init() {
        let input = DefaultConversationInputProvider()
        let capability = ConversationInputCapabilityAdapter(
            input: input,
            sender: nil,
            conversations: nil,
            conversationState: nil,
            metrics: nil
        )
        let viewModel = ConversationInputViewModel(capability: capability)
        self.viewModel = viewModel
        self.observer = ConversationInputObserver(capability: capability, viewModel: viewModel)

        // 闭包只捕获这些盒子，不捕获 `self`：init 未完成时引用 self 的属性
        // 是编译错误，而绑定闭包又必须强持有计数目标。
        let counter = counter
        let costs = costs
        let view = ChatInputEditorView(
            text: Binding(
                get: { viewModel.text },
                set: { newValue in
                    counter.recordText()
                    viewModel.setText(newValue)
                }
            ),
            height: Binding(
                get: { viewModel.inputHeight },
                set: { newValue in
                    counter.recordHeight()
                    viewModel.setInputHeight(newValue)
                }
            ),
            onSubmit: {},
            onCollapsedBlocksChanged: { _ in counter.recordBlockReport() },
            isFocused: .constant(false),
            cursorPosition: Binding(
                get: { viewModel.inputCursorPosition },
                set: { newValue in
                    counter.recordCursor()
                    viewModel.setCursorPosition(newValue)
                }
            ),
            isImageDragHovering: .constant(false)
        )

        let textView = EditorTextView(frame: NSRect(x: 0, y: 0, width: 640, height: 120))
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: 640,
            height: CGFloat.greatestFiniteMagnitude
        )
        self.textView = textView

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 640, height: 120))
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.documentView = textView
        self.scrollView = scrollView

        let coordinator = view.makeCoordinator()
        coordinator.attach(to: textView)
        self.coordinator = coordinator

        // 用代理而不是直接把协调器设为 delegate：代理能单独量出
        // 「我们自己的处理」耗时，与 AppKit 的排版耗时区分开。
        let measuringDelegate = MeasuringTextViewDelegate()
        measuringDelegate.inner = coordinator
        measuringDelegate.onCall = { cost in
            costs.recordAppSide(cost)
        }
        self.measuringDelegate = measuringDelegate
        textView.delegate = measuringDelegate

        viewModel.objectWillChange
            .sink { _ in
                counter.recordInvalidation()
            }
            .store(in: &cancellables)
    }

    /// 释放观察者订阅。
    ///
    /// 不写在 `deinit` 里：`deinit` 是非隔离上下文，调不到 `@MainActor` 的
    /// `cancel()`；测试用例显式收尾更清楚。
    func tearDown() {
        observer.cancel()
    }

    /// 模拟一次 IME 按键：组合态往前推进一格。
    ///
    /// AppKit 在组合态下同样会发 `textDidChange`。无头测试进程里文本系统
    /// 可能不产生真实编辑事件，因此这里在必要时补发一次通知，保证生产的
    /// `textDidChange` 路径一定被走到——否则后面的断言会变成空跑。
    func typeMarked(_ marked: String) {
        let callsBefore = measuringDelegate.callCount
        let start = DispatchTime.now()

        textView.setMarkedText(
            marked,
            selectedRange: NSRange(location: (marked as NSString).length, length: 0),
            replacementRange: NSRange(location: 0, length: (textView.string as NSString).length)
        )

        if measuringDelegate.callCount == callsBefore {
            measuringDelegate.performTextDidChange(
                Notification(name: NSText.didChangeNotification, object: textView)
            )
        }

        costs.recordTotal(Self.elapsedMs(since: start))
    }

    /// 模拟上屏：候选词被写进编辑器。
    func commit(_ committed: String) {
        let start = DispatchTime.now()

        textView.insertText(
            committed,
            replacementRange: NSRange(location: 0, length: (textView.string as NSString).length)
        )

        costs.recordTotal(Self.elapsedMs(since: start))
    }

    /// 打印实测数据。
    ///
    /// 这组数字的意义在于**对比**：应用侧耗时高说明是我们的问题，
    /// 应用侧接近零而总耗时高说明是机器负载 / AppKit 的问题。
    func printReport() {
        let app = appSideCosts
        let total = totalCosts
        guard !app.isEmpty else { return }

        let appMedian = Self.median(app)
        let appMax = app.max() ?? 0
        let totalMedian = Self.median(total)
        let totalMax = total.max() ?? 0

        print("""

        ── 中文 IME 逐键耗时实测 ──────────────────────────────
        组合态按键数：\(app.count)
        应用侧（Coordinator.textDidChange）：中位 \(String(format: "%.3f", appMedian))ms \
        / 最大 \(String(format: "%.3f", appMax))ms
        总耗时（含 AppKit 组合态排版）：      中位 \(String(format: "%.3f", totalMedian))ms \
        / 最大 \(String(format: "%.3f", totalMax))ms
        组合态期间的状态写入：文本 \(counter.textWrites) / 高度 \(counter.heightWrites) \
        / 光标 \(counter.cursorWrites) / 失效广播 \(counter.invalidations)
        ─────────────────────────────────────────────────────────

        """)
    }

    private static func elapsedMs(since start: DispatchTime) -> TimeInterval {
        Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
    }

    private static func median(_ values: [TimeInterval]) -> TimeInterval {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        return sorted[sorted.count / 2]
    }
}

/// 记录耗时的盒子。
///
/// 单独成类而不是直接用夹具的属性：绑定闭包与 delegate 代理都会强引用它，
/// 若它们反过来引用夹具就会形成保留环。
@MainActor
private final class CostRecorder {
    /// 应用侧单次耗时（毫秒）。
    private(set) var appSide: [TimeInterval] = []
    /// 单次完整耗时（毫秒）。
    private(set) var total: [TimeInterval] = []

    func recordAppSide(_ cost: TimeInterval) { appSide.append(cost) }
    func recordTotal(_ cost: TimeInterval) { total.append(cost) }
}

/// 计数写入次数的盒子。
///
/// 单独成类而不是直接用夹具的属性：绑定闭包会强引用它，若闭包反过来
/// 引用夹具就会形成保留环。
@MainActor
private final class WriteCounter {
    private(set) var textWrites = 0
    private(set) var heightWrites = 0
    private(set) var cursorWrites = 0
    private(set) var blockReports = 0
    private(set) var invalidations = 0

    func recordText() { textWrites += 1 }
    func recordHeight() { heightWrites += 1 }
    func recordCursor() { cursorWrites += 1 }
    func recordBlockReport() { blockReports += 1 }
    func recordInvalidation() { invalidations += 1 }
}

/// 包一层 `NSTextViewDelegate`，只为把「我们自己的处理」单独计时。
///
/// `@MainActor` 是必需的：`NSTextViewDelegate` 的回调在 SDK 里就是主线程隔离的，
/// 代理不在同一隔离域里调用协调器会被 Swift 6 判为跨 actor 调用。
@MainActor
private final class MeasuringTextViewDelegate: NSObject, NSTextViewDelegate {
    weak var inner: ChatInputEditorView.Coordinator?
    /// 每次 delegate 回调的耗时（毫秒）。
    var onCall: ((TimeInterval) -> Void)?
    /// 已收到的回调次数。
    private(set) var callCount = 0

    func performTextDidChange(_ notification: Notification) {
        let start = DispatchTime.now()
        inner?.textDidChange(notification)
        callCount += 1
        onCall?(Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000)
    }

    func textDidChange(_ notification: Notification) {
        performTextDidChange(notification)
    }

    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        inner?.textView(textView, doCommandBy: commandSelector) ?? false
    }
}
