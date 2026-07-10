import AppKit
import os

extension TextView {
    /// 排查 CPU 占用：鼠标拖拽自动滚动定时器(45Hz)若 stop 路径遗漏会导致持续 100% CPU。
    /// 仅在 setup/disable 打 lifecycle 日志，确认是否泄漏。subsystem 对齐 com.coffic.lumi。
    private static let mouseDragLogger = Logger(subsystem: "com.coffic.lumi", category: "editor.mouse-autoscroll")
    private static let mouseDragVerbose = false

    override public func mouseDown(with event: NSEvent) {
        // Set cursor
        guard isSelectable,
              event.type == .leftMouseDown,
              let offset = layoutManager.textOffsetAtPoint(self.convert(event.locationInWindow, from: nil)) else {
            super.mouseDown(with: event)
            return
        }

        if let content = layoutManager.contentRun(at: offset),
           case let .attachment(attachment) = content.data, event.clickCount < 3 {
            handleAttachmentClick(event: event, offset: offset, attachment: attachment)
            return
        }

        switch event.clickCount {
        case 1:
            handleSingleClick(event: event, offset: offset)
        case 2:
            handleDoubleClick(event: event)
        case 3:
            handleTripleClick(event: event)
        default:
            break
        }

        setUpMouseAutoscrollTimer()
    }

    /// Single click, if control-shift we add a cursor
    /// if shift, we extend the selection to the click location
    /// else we set the cursor
    fileprivate func handleSingleClick(event: NSEvent, offset: Int) {
        cursorSelectionMode = .character

        guard isEditable else {
            super.mouseDown(with: event)
            return
        }
        let eventFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if eventFlags == [.control, .shift] {
            unmarkText()
            selectionManager.addSelectedRange(NSRange(location: offset, length: 0))
        } else if eventFlags.contains(.shift) {
            unmarkText()
            shiftClickExtendSelection(to: offset)
        } else {
            selectionManager.setSelectedRange(NSRange(location: offset, length: 0))
            unmarkTextIfNeeded()
        }
    }

    fileprivate func handleDoubleClick(event: NSEvent) {
        cursorSelectionMode = .word

        guard !event.modifierFlags.contains(.shift) else {
            super.mouseDown(with: event)
            return
        }
        unmarkText()
        selectWord(nil)
    }

    fileprivate func handleTripleClick(event: NSEvent) {
        cursorSelectionMode = .line

        guard !event.modifierFlags.contains(.shift) else {
            super.mouseDown(with: event)
            return
        }
        unmarkText()
        selectLine(nil)
    }

    fileprivate func handleAttachmentClick(event: NSEvent, offset: Int, attachment: AnyTextAttachment) {
        switch event.clickCount {
        case 1:
            selectionManager.setSelectedRange(attachment.range)
        case 2:
            performAttachmentAction(attachment: attachment)
        default:
            break
        }
    }

    func performAttachmentAction(attachment: AnyTextAttachment) {
        let action = attachment.attachment.attachmentAction()
        switch action {
        case .none:
            return
        case .discard:
            layoutManager.attachments.remove(atOffset: attachment.range.location)
            selectionManager.setSelectedRange(NSRange(location: attachment.range.location, length: 0))
        case let .replace(text):
            replaceCharacters(in: attachment.range, with: text)
        }
    }

    override public func mouseUp(with event: NSEvent) {
        mouseDragAnchor = nil
        disableMouseAutoscrollTimer()
        super.mouseUp(with: event)
    }

    override public func mouseDragged(with event: NSEvent) {
        guard !(inputContext?.handleEvent(event) ?? false) && isSelectable && !isDragging else {
            return
        }

        // We receive global events because our view received the drag event, but we need to clamp the potentially
        // out-of-bounds positions to a position our layout manager can deal with.
        let locationInWindow = convert(event.locationInWindow, from: nil)
        let locationInView = CGPoint(
            x: max(0.0, min(locationInWindow.x, frame.width)),
            y: max(0.0, min(locationInWindow.y, frame.height))
        )

        if mouseDragAnchor == nil {
            mouseDragAnchor = locationInView
            super.mouseDragged(with: event)
        } else {
            guard let mouseDragAnchor,
                  let startPosition = layoutManager.textOffsetAtPoint(mouseDragAnchor),
                  let endPosition = layoutManager.textOffsetAtPoint(locationInView) else {
                return
            }

            let modifierFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if modifierFlags.contains(.option) {
                dragColumnSelection(mouseDragAnchor: mouseDragAnchor, locationInView: locationInView)
            } else {
                dragSelection(startPosition: startPosition, endPosition: endPosition, mouseDragAnchor: mouseDragAnchor)
            }

            setNeedsDisplay()
            self.autoscroll(with: event)
        }
    }

    /// Extends the current selection to the offset. Only used when the user shift-clicks a location in the document.
    ///
    /// If the offset is within the selection, trims the selection from the nearest edge (start or end) towards the
    /// clicked offset.
    /// Otherwise, extends the selection to the clicked offset.
    ///
    /// - Parameter offset: The offset clicked on.
    fileprivate func shiftClickExtendSelection(to offset: Int) {
        // Use the last added selection, this is behavior copied from Xcode.
        guard var selectedRange = selectionManager.textSelections.last?.range else { return }
        if selectedRange.contains(offset) {
            if offset - selectedRange.location <= selectedRange.max - offset {
                selectedRange.length -= offset - selectedRange.location
                selectedRange.location = offset
            } else {
                selectedRange.length -= selectedRange.max - offset
            }
        } else {
            selectedRange.formUnion(NSRange(
                start: min(offset, selectedRange.location),
                end: max(offset, selectedRange.max)
            ))
        }
        selectionManager.setSelectedRange(selectedRange)
        setNeedsDisplay()
    }

    // MARK: - Mouse Autoscroll

    /// Sets up a timer that fires at a predetermined period to autoscroll the text view.
    /// Ensure the timer is disabled using ``disableMouseAutoscrollTimer``.
    func setUpMouseAutoscrollTimer() {
        mouseDragTimer?.invalidate()
        // https://cocoadev.github.io/AutoScrolling/ (fired at ~45Hz)
        mouseDragTimer = Timer.scheduledTimer(withTimeInterval: 0.022, repeats: true) { [weak self] _ in
            if let event = self?.window?.currentEvent, event.type == .leftMouseDragged {
                self?.mouseDragged(with: event)
                self?.autoscroll(with: event)
            }
        }
        if Self.mouseDragVerbose { Self.mouseDragLogger.info("🔥 | 🖱️ TextView                      | ⏱️ 启动鼠标自动滚动定时器(45Hz)——若长期未 disable 将持续吃满主线程") }
    }

    /// Disables the mouse drag timer started by ``setUpMouseAutoscrollTimer``
    func disableMouseAutoscrollTimer() {
        if Self.mouseDragVerbose, mouseDragTimer != nil { Self.mouseDragLogger.info("🔥 | 🖱️ TextView                      | ⏱️ 停止鼠标自动滚动定时器") }
        mouseDragTimer?.invalidate()
        mouseDragTimer = nil
    }

    // MARK: - Drag Selection

    private func dragSelection(startPosition: Int, endPosition: Int, mouseDragAnchor: CGPoint) {
        switch cursorSelectionMode {
        case .character:
            guard let range = TextViewDragSelectionRange.betweenOffsets(startPosition, endPosition) else { return }
            selectionManager.setSelectedRange(range)

        case .word:
            let startWordRange = findWordBoundary(at: startPosition)
            let endWordRange = findWordBoundary(at: endPosition)

            guard let range = TextViewDragSelectionRange.enclosing(startWordRange, endWordRange) else { return }
            selectionManager.setSelectedRange(range)

        case .line:
            let startLineRange = findLineBoundary(at: startPosition)
            let endLineRange = findLineBoundary(at: endPosition)

            guard let range = TextViewDragSelectionRange.enclosing(startLineRange, endLineRange) else { return }
            selectionManager.setSelectedRange(range)
        }
    }

    private func dragColumnSelection(mouseDragAnchor: CGPoint, locationInView: CGPoint) {
        selectColumns(betweenPointA: mouseDragAnchor, pointB: locationInView)
    }
}

enum TextViewDragSelectionRange {
    static func betweenOffsets(_ lhs: Int, _ rhs: Int) -> NSRange? {
        guard lhs >= 0, rhs >= 0 else {
            return nil
        }

        let lowerBound = min(lhs, rhs)
        let upperBound = max(lhs, rhs)
        return NSRange(location: lowerBound, length: upperBound - lowerBound)
    }

    static func enclosing(_ lhs: NSRange, _ rhs: NSRange) -> NSRange? {
        guard lhs.location >= 0, lhs.length >= 0, rhs.location >= 0, rhs.length >= 0,
              let lhsUpperBound = upperBound(for: lhs),
              let rhsUpperBound = upperBound(for: rhs) else {
            return nil
        }

        let lowerBound = min(lhs.location, rhs.location)
        let upperBound = max(lhsUpperBound, rhsUpperBound)
        guard upperBound >= lowerBound else {
            return nil
        }

        return NSRange(location: lowerBound, length: upperBound - lowerBound)
    }

    private static func upperBound(for range: NSRange) -> Int? {
        let upperBound = range.location.addingReportingOverflow(range.length)
        guard !upperBound.overflow else {
            return nil
        }

        return upperBound.partialValue
    }
}
