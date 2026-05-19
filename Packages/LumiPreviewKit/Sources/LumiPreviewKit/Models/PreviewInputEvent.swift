import Foundation

public extension LumiPreviewFacade {

    /// 跨进程的输入事件 envelope。
    ///
    /// 主进程在 `PreviewSurfaceView` 捕获 `NSEvent`，转成此结构通过 stdio 送给子进程；
    /// 子进程 `PreviewEventDispatcher` 把它合成 `NSEvent` 并注入离屏窗口。
    ///
    /// 坐标说明：
    /// - `(x, y)` 都是 **bottom-left 原点**、单位为 **point**，相对于子进程的 hosting view bounds。
    /// - 主进程 `PreviewSurfaceView` 与子进程 hosting view 通过 `resizeSurface` 保证 point 尺寸一致，
    ///   因此可以直接传 view-local 坐标，无需缩放。
    enum PreviewInputEvent: Codable, Sendable, Equatable {
        case mouse(MouseEvent)
        case scrollWheel(ScrollWheelEvent)
        case key(KeyEvent)
        case flagsChanged(modifiers: ModifierFlags)
        case textInput(TextInputEvent)
        case dragAndDrop(DragDropEvent)
        case touchBar(TouchBarEvent)
    }

    // MARK: - 鼠标

    struct MouseEvent: Codable, Sendable, Equatable {
        public enum Phase: String, Codable, Sendable, Equatable {
            case down
            case up
            case moved
            case dragged
            case entered
            case exited
        }

        public enum Button: Int, Codable, Sendable, Equatable {
            case left = 0
            case right = 1
            case other = 2
        }

        public let phase: Phase
        public let button: Button
        public let x: Double
        public let y: Double
        public let clickCount: Int
        public let modifiers: ModifierFlags

        public init(
            phase: Phase,
            button: Button,
            x: Double,
            y: Double,
            clickCount: Int,
            modifiers: ModifierFlags
        ) {
            self.phase = phase
            self.button = button
            self.x = x
            self.y = y
            self.clickCount = clickCount
            self.modifiers = modifiers
        }
    }

    // MARK: - 拖放

    struct DragDropEvent: Codable, Sendable, Equatable {
        public enum Phase: String, Codable, Sendable, Equatable {
            case entered
            case updated
            case exited
            case perform
        }

        public enum Item: Codable, Sendable, Equatable {
            case string(String)
            case fileURL(String)
        }

        public let phase: Phase
        public let x: Double
        public let y: Double
        public let items: [Item]
        public let modifiers: ModifierFlags

        public init(
            phase: Phase,
            x: Double,
            y: Double,
            items: [Item],
            modifiers: ModifierFlags
        ) {
            self.phase = phase
            self.x = x
            self.y = y
            self.items = items
            self.modifiers = modifiers
        }
    }

    // MARK: - Touch Bar

    struct TouchBarEvent: Codable, Sendable, Equatable {
        public enum Phase: String, Codable, Sendable, Equatable {
            case itemPressed
        }

        /// `NSTouchBarItem.Identifier.rawValue` for the target item.
        public let itemIdentifier: String
        public let phase: Phase
        public let modifiers: ModifierFlags

        public init(
            itemIdentifier: String,
            phase: Phase = .itemPressed,
            modifiers: ModifierFlags = []
        ) {
            self.itemIdentifier = itemIdentifier
            self.phase = phase
            self.modifiers = modifiers
        }
    }

    // MARK: - 滚轮

    struct ScrollWheelEvent: Codable, Sendable, Equatable {
        public enum Phase: String, Codable, Sendable, Equatable {
            case began
            case changed
            case ended
            case mayBegin
            case cancelled
            case stationary
            case none
        }

        public let x: Double
        public let y: Double
        public let deltaX: Double
        public let deltaY: Double
        public let scrollingDeltaX: Double
        public let scrollingDeltaY: Double
        public let hasPreciseScrollingDeltas: Bool
        public let modifiers: ModifierFlags
        public let phase: Phase
        public let momentumPhase: Phase

        public init(
            x: Double,
            y: Double,
            deltaX: Double,
            deltaY: Double,
            scrollingDeltaX: Double,
            scrollingDeltaY: Double,
            hasPreciseScrollingDeltas: Bool,
            modifiers: ModifierFlags,
            phase: Phase,
            momentumPhase: Phase
        ) {
            self.x = x
            self.y = y
            self.deltaX = deltaX
            self.deltaY = deltaY
            self.scrollingDeltaX = scrollingDeltaX
            self.scrollingDeltaY = scrollingDeltaY
            self.hasPreciseScrollingDeltas = hasPreciseScrollingDeltas
            self.modifiers = modifiers
            self.phase = phase
            self.momentumPhase = momentumPhase
        }
    }

    // MARK: - 键盘

    struct KeyEvent: Codable, Sendable, Equatable {
        public enum Phase: String, Codable, Sendable, Equatable {
            case down
            case up
        }

        public let phase: Phase
        public let keyCode: UInt16
        public let characters: String?
        public let charactersIgnoringModifiers: String?
        public let isARepeat: Bool
        public let modifiers: ModifierFlags

        public init(
            phase: Phase,
            keyCode: UInt16,
            characters: String?,
            charactersIgnoringModifiers: String?,
            isARepeat: Bool,
            modifiers: ModifierFlags
        ) {
            self.phase = phase
            self.keyCode = keyCode
            self.characters = characters
            self.charactersIgnoringModifiers = charactersIgnoringModifiers
            self.isARepeat = isARepeat
            self.modifiers = modifiers
        }
    }

    // MARK: - 文本输入 / IME

    struct TextInputEvent: Codable, Sendable, Equatable {
        public enum Phase: String, Codable, Sendable, Equatable {
            case insertText
            case setMarkedText
            case unmarkText
        }

        public let phase: Phase
        public let text: String
        public let selectedRange: Range
        public let replacementRange: Range

        public init(
            phase: Phase,
            text: String,
            selectedRange: Range = .notFound,
            replacementRange: Range = .notFound
        ) {
            self.phase = phase
            self.text = text
            self.selectedRange = selectedRange
            self.replacementRange = replacementRange
        }
    }

    struct Range: Codable, Sendable, Equatable {
        public let location: Int
        public let length: Int

        public init(location: Int, length: Int) {
            self.location = location
            self.length = length
        }

        public static let notFound = Range(location: NSNotFound, length: 0)
    }

    // MARK: - 修饰键

    /// 跨进程独立的修饰键 OptionSet，避免直接序列化 `NSEvent.ModifierFlags`。
    struct ModifierFlags: OptionSet, Codable, Sendable, Equatable {
        public let rawValue: UInt32

        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }

        public static let capsLock = ModifierFlags(rawValue: 1 << 0)
        public static let shift    = ModifierFlags(rawValue: 1 << 1)
        public static let control  = ModifierFlags(rawValue: 1 << 2)
        public static let option   = ModifierFlags(rawValue: 1 << 3)
        public static let command  = ModifierFlags(rawValue: 1 << 4)
        public static let function = ModifierFlags(rawValue: 1 << 5)
        public static let numericPad = ModifierFlags(rawValue: 1 << 6)
        public static let help     = ModifierFlags(rawValue: 1 << 7)
    }
}
