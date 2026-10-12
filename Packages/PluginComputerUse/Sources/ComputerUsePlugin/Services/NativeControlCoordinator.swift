import AppKit
import Combine
import Foundation

@MainActor
final class NativeControlCoordinator: ObservableObject {
    enum Phase: Equatable { case idle, permission, preparing, running, paused }
    static let shared = NativeControlCoordinator()

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var applicationName = ""
    @Published private(set) var reason = ""
    @Published private(set) var progress = ""
    private(set) var session: NativeControlSession?
    private var monitor: NativeInputMonitor?
    private var banner: NativeControlBannerController?
    private var approved = false
    private var resumed = false
    private var stopped = false
    private let defaults: UserDefaults
    private let presentsUI: Bool
    private var bundleID = ""
    private var queue: [UUID] = []
    private let permissionKey = "ComputerUse.nativeAllowedBundleIdentifiers"

    init(defaults: UserDefaults = .standard, presentsUI: Bool = true) {
        self.defaults = defaults
        self.presentsUI = presentsUI
    }

    var blocksLumi: Bool { phase == .preparing || phase == .running }
    var isBusy: Bool { session != nil }

    func acquireWhenAvailable(application: String, bundleID: String, reason: String) async throws -> NativeControlSession {
        let ticket = UUID()
        queue.append(ticket)
        defer { queue.removeAll { $0 == ticket } }
        let deadline = ContinuousClock.now.advanced(by: .seconds(60))
        while isBusy || queue.first != ticket {
            try Task.checkCancellation()
            if .now >= deadline { throw ComputerUseError.invalidArguments("Desktop control is busy. Observe again after the current operation finishes.") }
            try await Task.sleep(for: .milliseconds(100))
        }
        try Task.checkCancellation()
        return try acquire(application: application, bundleID: bundleID, reason: reason)
    }

    /// A real lease is held across awaits. Actor isolation alone is reentrant.
    func acquire(application: String, bundleID: String, reason: String) throws -> NativeControlSession {
        guard session == nil else {
            throw ComputerUseError.invalidArguments("Another computer operation is active or awaiting the user. Wait; do not retry through shell commands.")
        }
        let session = NativeControlSession()
        self.session = session
        applicationName = application
        self.bundleID = bundleID
        self.reason = String(reason.prefix(180))
        progress = ""
        approved = (defaults.stringArray(forKey: permissionKey) ?? []).contains(bundleID)
        resumed = false
        stopped = false
        phase = approved ? .preparing : .permission
        if presentsUI {
            let banner = NativeControlBannerController(state: self)
            self.banner = banner
            banner.show()
        }
        return session
    }

    func prepare(_ session: NativeControlSession) async throws {
        let permissionDeadline = ContinuousClock.now.advanced(by: .seconds(120))
        while !approved {
            try validateOwner(session)
            if .now >= permissionDeadline { throw NativeControlInterruption.timedOut }
            try await Task.sleep(for: .milliseconds(100))
        }
        try validateOwner(session)
        phase = .preparing
        // Start monitoring after consent: the consent click must not pause itself.
        try await Task.sleep(for: .milliseconds(250))
        try validateOwner(session)
        if presentsUI {
            let monitor = NativeInputMonitor(session: session)
            try monitor.start()
            self.monitor = monitor
        }
        for remaining in stride(from: 20, through: 1, by: -1) {
            try validateOwner(session)
            progress = computerUseText("Starting in {seconds} seconds", ["seconds": String((remaining + 9) / 10)])
            try await Task.sleep(for: .milliseconds(100))
        }
        try validateOwner(session)
        session.start()
        phase = .running
    }

    func updateProgress(_ text: String) { progress = text }
    func avoidBanner(at point: CGPoint) { banner?.avoid(point) }

    func validateOwner(_ session: NativeControlSession) throws {
        guard self.session === session, !stopped else { throw NativeControlInterruption.stopped }
        try session.check()
    }

    /// Continue releases the paused job with a re-observe result. Never replay a
    /// saved batch against a window the user may have changed in the meantime.
    func waitForUserAfterInterruption(_ session: NativeControlSession) async throws {
        monitor?.stop()
        monitor = nil
        phase = .paused
        progress = computerUseText("You can use your computer.")
        let deadline = ContinuousClock.now.advanced(by: .seconds(300))
        while !resumed {
            try Task.checkCancellation()
            guard self.session === session, !stopped else { throw NativeControlInterruption.stopped }
            if .now >= deadline { throw NativeControlInterruption.timedOut }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw ComputerUseError.invalidArguments("The user resumed. Previous actions were interrupted and may have partially completed. Call accessibility_observe and computer_observe again; verify current state before issuing new actions.")
    }

    func allow() {
        guard phase == .permission else { return }
        var allowed = Set(defaults.stringArray(forKey: permissionKey) ?? [])
        allowed.insert(bundleID)
        defaults.set(allowed.sorted(), forKey: permissionKey)
        approved = true
    }

    func resume() { if phase == .paused { resumed = true } }

    func stop() {
        // An explicit Stop revokes the remembered permission. A model retry must
        // not silently start another batch after the user has stopped this one.
        var allowed = Set(defaults.stringArray(forKey: permissionKey) ?? [])
        allowed.remove(bundleID)
        defaults.set(allowed.sorted(), forKey: permissionKey)
        cleanup()
    }

    private func cleanup() {
        stopped = true
        session?.interrupt(.stopped)
        monitor?.stop()
        monitor = nil
        phase = .idle
        banner?.close()
        banner = nil
    }

    func release(_ session: NativeControlSession) {
        guard self.session === session else { return }
        cleanup()
        self.session = nil
    }

    func shutdown() {
        cleanup()
        session = nil
    }
}
