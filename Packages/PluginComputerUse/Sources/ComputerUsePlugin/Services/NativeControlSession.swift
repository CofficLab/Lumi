import CoreGraphics
import Foundation

enum NativeControlInterruption: Error, Equatable {
    case userInput, focusChanged, stopped, timedOut
}

/// The event-tap callback can revoke the lease synchronously, without waiting for
/// the main actor. Every synthesized input checks this lease before posting.
final class NativeControlSession: @unchecked Sendable {
    static let eventMarker: Int64 = 0x4C554D49435541
    let id = UUID()
    private let lock = NSLock()
    private var interruption: NativeControlInterruption?
    private var deadline: ContinuousClock.Instant?

    func start(duration: Duration = .seconds(20)) {
        lock.withLock { deadline = .now.advanced(by: duration) }
    }

    func interrupt(_ reason: NativeControlInterruption) {
        lock.withLock { if interruption == nil { interruption = reason } }
    }

    func check() throws {
        try Task.checkCancellation()
        try lock.withLock {
            if let interruption { throw interruption }
            if let deadline, ContinuousClock.now >= deadline {
                interruption = .timedOut
                throw NativeControlInterruption.timedOut
            }
        }
    }

    static func isOwnEvent(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.eventSourceUserData) == eventMarker &&
        event.getIntegerValueField(.eventSourceUnixProcessID) == Int64(ProcessInfo.processInfo.processIdentifier)
    }
}

final class NativeInputMonitor {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private let session: NativeControlSession

    init(session: NativeControlSession) { self.session = session }

    func start() throws {
        let types: [CGEventType] = [.mouseMoved, .leftMouseDown, .rightMouseDown, .otherMouseDown,
                                   .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
                                   .scrollWheel, .keyDown, .flagsChanged]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        let callback: CGEventTapCallBack = { _, type, event, pointer in
            guard let pointer else { return Unmanaged.passUnretained(event) }
            let session = Unmanaged<NativeControlSession>.fromOpaque(pointer).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                // Lost monitoring must never leave input injection running unattended.
                session.interrupt(.stopped)
            } else if !NativeControlSession.isOwnEvent(event) {
                session.interrupt(.userInput)
            }
            return Unmanaged.passUnretained(event)
        }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                         options: .listenOnly, eventsOfInterest: mask,
                                         callback: callback, userInfo: Unmanaged.passUnretained(session).toOpaque()) else {
            throw ComputerUseError.invalidArguments("Unable to monitor user input. Enable Accessibility/Input Monitoring for Lumi before native control.")
        }
        self.tap = tap
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
    }
    deinit { stop() }
}
