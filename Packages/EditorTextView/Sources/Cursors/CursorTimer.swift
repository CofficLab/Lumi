//
//  CursorTimer.swift
//  EditorTextView
//
//  Created by Khan Winter on 1/16/24.
//

import Foundation
import AppKit
import os

class CursorTimer {
    /// # Properties

    /// The timer that publishes the cursor toggle timer.
    private var timer: Timer?
    /// Maps to all cursor views, uses weak memory to not cause a strong reference cycle.
    private var cursors: NSHashTable<CursorView> = .init(options: .weakMemory)
    /// Tracks whether cursors are hidden or not.
    var shouldHide: Bool = false

    /// 排查 CPU 占用：每个聚焦编辑器都会启动一个 0.5Hz 闪烁定时器。
    /// 用 lifecycle 日志确认是否有泄漏（reset 后没 stop）。subsystem 对齐 com.coffic.lumi。
    /// 本包不依赖 SuperLogKit，故用原生 os.Logger + 本地 verbose 开关，排查完改 false 即可。
    private static let emoji = "⏱️"
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "editor.cursor")
    private static let verbose = true

    // MARK: - Methods

    /// Resets the cursor blink timer.
    /// - Parameter newBlinkDuration: The duration to blink, leave as nil to never blink.
    func resetTimer(newBlinkDuration: TimeInterval? = 0.5) {
        timer?.invalidate()

        guard let newBlinkDuration else {
            notifyCursors(shouldHide: true)
            return
        }

        shouldHide = false
        notifyCursors(shouldHide: shouldHide)

        if Self.verbose { Self.logger.info("\(Self.emoji) 启动闪烁定时器 \(newBlinkDuration)s") }
        timer = Timer.scheduledTimer(withTimeInterval: newBlinkDuration, repeats: true) { [weak self] _ in
            self?.assertMain()
            self?.shouldHide.toggle()
            guard let shouldHide = self?.shouldHide else { return }
            self?.notifyCursors(shouldHide: shouldHide)
        }
    }

    func stopTimer() {
        if Self.verbose, timer != nil { Self.logger.info("\(Self.emoji) 停止闪烁定时器") }
        shouldHide = true
        notifyCursors(shouldHide: true)
        cursors.removeAllObjects()
        timer?.invalidate()
        timer = nil
    }

    /// Notify all cursors of a new blink state.
    /// - Parameter shouldHide: Whether or not the cursors should be hidden or not.
    private func notifyCursors(shouldHide: Bool) {
        for cursor in cursors.allObjects {
            cursor.blinkTimer(shouldHide)
        }
    }

    /// Register a new cursor view with the timer.
    /// - Parameter newCursor: The cursor to blink.
    func register(_ newCursor: CursorView) {
        cursors.add(newCursor)
    }

    deinit {
        timer?.invalidate()
        timer = nil
        cursors.removeAllObjects()
    }

    private func assertMain() {
#if DEBUG
        assert(Thread.isMainThread, "CursorTimer used from non-main thread")
#endif
    }
}
