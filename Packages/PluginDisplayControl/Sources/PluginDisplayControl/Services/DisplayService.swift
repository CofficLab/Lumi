import CoreGraphics
import Foundation
import LumiLoggingKit
import os

// MARK: - DisplayServices Bridge (built-in display)

private final class DisplayServicesBridge: Sendable {
    func getBrightness(displayID: CGDirectDisplayID) -> Float? {
        // 符号缺失时降级为"读不到"，而不是调用 NULL 地址（见 Issue #122）。
        guard let getBrightness = PrivateDisplaySymbol.displayServicesGetBrightness else { return nil }
        var value: Float = -1
        let result = getBrightness(displayID, &value)
        guard result == 0, value >= 0 else { return nil }
        return min(1, max(0, value))
    }

    func setBrightness(displayID: CGDirectDisplayID, value: Float) -> Bool {
        guard let setBrightness = PrivateDisplaySymbol.displayServicesSetBrightness else { return false }
        let clampedValue = min(1, max(0, value))
        return setBrightness(displayID, clampedValue) == 0
    }
}

// MARK: - DisplayService

@MainActor
final class DisplayService: ObservableObject, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "service.display")
    nonisolated static let emoji = "🖥"
    nonisolated static let verbose = false

    static let shared = DisplayService()

    @Published private(set) var displays: [ControlledDisplay] = []
    @Published private var pendingValues: [CGDirectDisplayID: [DisplayControlKind: Double]] = [:]

    private let ddc = DisplayDDCBridge()
    private let displayServicesBridge = DisplayServicesBridge()
    private let store = DisplayControlPluginLocalStore.shared
    private var fallbackValues: [CGDirectDisplayID: [DisplayControlKind: Double]] = [:]

    // Debounce
    private var debounceTimers: [ControlKey: Task<Void, Never>] = [:]

    private init() {}

    // MARK: - Refresh

    func refresh() {
        let ddc = self.ddc
        let displayServicesBridge = self.displayServicesBridge
        let store = self.store

        Task { @MainActor in
            let displayIDs = Self.onlineDisplayIDs()
            ddc.refresh(displayIDs: displayIDs)

            var detected: [ControlledDisplay] = []
            for id in displayIDs {
                let isBuiltIn = CGDisplayIsBuiltin(id) != 0
                let name = Self.displayName(for: id, isBuiltIn: isBuiltIn)
                let storageID = Self.displayStorageID(for: id, name: name, isBuiltIn: isBuiltIn)
                let appleBrightness = isBuiltIn ? displayServicesBridge.getBrightness(displayID: id) : nil
                let hasDDCService = !isBuiltIn && ddc.hasService(for: id)
                let ddcBrightness = isBuiltIn ? nil : ddc.read(.brightness, displayID: id)
                let ddcVolume = isBuiltIn ? nil : ddc.read(.volume, displayID: id)
                let ddcContrast = isBuiltIn ? nil : ddc.read(.contrast, displayID: id)
                let storedBrightness = Self.storedValue(for: .brightness, displayStorageID: storageID, store: store)
                let storedVolume = Self.storedValue(for: .volume, displayStorageID: storageID, store: store)
                let storedContrast = Self.storedValue(for: .contrast, displayStorageID: storageID, store: store)

                let display = ControlledDisplay(
                    id: id,
                    storageID: storageID,
                    name: name,
                    isBuiltIn: isBuiltIn,
                    supportsBrightness: Self.isControlSupported(
                        .brightness, isBuiltIn: isBuiltIn, appleBrightness: appleBrightness,
                        ddcValue: ddcBrightness, storedValue: storedBrightness, hasDDCService: hasDDCService
                    ),
                    supportsVolume: Self.isControlSupported(
                        .volume, isBuiltIn: isBuiltIn, appleBrightness: appleBrightness,
                        ddcValue: ddcVolume, storedValue: storedVolume, hasDDCService: hasDDCService
                    ),
                    supportsContrast: Self.isControlSupported(
                        .contrast, isBuiltIn: isBuiltIn, appleBrightness: appleBrightness,
                        ddcValue: ddcContrast, storedValue: storedContrast, hasDDCService: hasDDCService
                    ),
                    brightness: appleBrightness.map { Double($0 * 100) }
                        ?? ddcBrightness
                        ?? storedBrightness
                        ?? DisplayControlKind.brightness.defaultValue,
                    volume: ddcVolume
                        ?? storedVolume
                        ?? DisplayControlKind.volume.defaultValue,
                    contrast: ddcContrast
                        ?? storedContrast
                        ?? DisplayControlKind.contrast.defaultValue
                )
                detected.append(display)
            }

            self.displays = detected
            for display in detected {
                self.seedFallbackValues(for: display)
            }
        }
    }

    // MARK: - Value Access

    func value(for control: DisplayControlKind, displayID: CGDirectDisplayID) -> Double {
        if let pendingValue = pendingValues[displayID]?[control] {
            return pendingValue
        }
        if let display = displays.first(where: { $0.id == displayID }) {
            return display.value(for: control)
        }
        return fallbackValues[displayID]?[control] ?? control.defaultValue
    }

    // MARK: - Write (debounced)

    func restoreDefaults() {
        debounceTimers.values.forEach { $0.cancel() }
        debounceTimers.removeAll()
        pendingValues.removeAll()

        for display in displays {
            for control in [DisplayControlKind.brightness, .volume, .contrast] {
                Self.removeStoredValue(
                    for: control,
                    displayStorageID: display.storageID,
                    store: store
                )
            }
        }

        for index in displays.indices {
            var display = displays[index]
            for control in [DisplayControlKind.brightness, .volume, .contrast] {
                guard display.supports(control) else { continue }
                let defaultValue = control.defaultValue
                display.setValue(defaultValue, for: control)
                fallbackValues[display.id, default: [:]][control] = defaultValue
                let key = ControlKey(displayID: display.id, control: control)
                performWrite(defaultValue, for: control, displayID: display.id, key: key)
            }
            displays[index] = display
        }
    }

    func setValue(_ value: Double, for control: DisplayControlKind, displayID: CGDirectDisplayID) {
        let clampedValue = min(100, max(0, value))
        guard let display = displays.first(where: { $0.id == displayID }) else { return }
        guard display.supports(control) else { return }

        let key = ControlKey(displayID: displayID, control: control)
        pendingValues[displayID, default: [:]][control] = clampedValue

        // Cancel existing debounce timer
        debounceTimers[key]?.cancel()

        // Create debounced write task (150ms)
        debounceTimers[key] = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000) // 150ms
            guard !Task.isCancelled else { return }
            self.performWrite(clampedValue, for: control, displayID: displayID, key: key)
        }
    }

    // MARK: - Private

    private func performWrite(
        _ value: Double,
        for control: DisplayControlKind,
        displayID: CGDirectDisplayID,
        key: ControlKey
    ) {
        guard let display = displays.first(where: { $0.id == displayID }) else { return }

        let success: Bool
        if display.isBuiltIn {
            switch control {
            case .brightness:
                success = displayServicesBridge.setBrightness(displayID: display.id, value: Float(value / 100))
            case .volume, .contrast:
                success = false
            }
        } else {
            success = ddc.write(value, for: control, displayID: display.id)
        }

        let currentPendingValue = pendingValues[key.displayID]?[key.control]
        let isCurrentResult = currentPendingValue.map { abs($0 - value) < 0.001 } ?? false

        if success {
            if !display.isBuiltIn {
                Self.saveStoredValue(value, for: control, displayStorageID: display.storageID, store: store)
            }
            updateLocalValue(value, for: control, displayID: key.displayID)
            fallbackValues[key.displayID, default: [:]][key.control] = value
        } else {
            // DDC writes can fail transiently (busy bus, monitor OSD, etc.).
            // Keep the control enabled and persist the desired value locally.
            if !display.isBuiltIn {
                Self.saveStoredValue(value, for: control, displayStorageID: display.storageID, store: store)
            }
            updateLocalValue(value, for: control, displayID: key.displayID)
            fallbackValues[key.displayID, default: [:]][key.control] = value
            Self.logger.warning(
                "\(Self.t)Display control write failed for \(control.storageKey, privacy: .public) on display \(displayID, privacy: .public)"
            )
        }

        if isCurrentResult {
            pendingValues[key.displayID]?[key.control] = nil
            if pendingValues[key.displayID]?.isEmpty == true {
                pendingValues[key.displayID] = nil
            }
        }

        debounceTimers[key] = nil
    }

    private func updateLocalValue(_ value: Double, for control: DisplayControlKind, displayID: CGDirectDisplayID) {
        guard let index = displays.firstIndex(where: { $0.id == displayID }) else { return }
        displays[index].setValue(value, for: control)
    }

    private func seedFallbackValues(for display: ControlledDisplay) {
        fallbackValues[display.id] = [
            .brightness: display.brightness,
            .volume: display.volume,
            .contrast: display.contrast
        ]
    }

    // MARK: - Static Display Info Helpers (nonisolated safe)

    /// 只有读到 VCP 值或有历史存储值才算支持；DDC 通道存在本身不是逐控制的能力证据。
    nonisolated static func isControlSupported(
        _ control: DisplayControlKind,
        isBuiltIn: Bool,
        appleBrightness: Float?,
        ddcValue: Double?,
        storedValue: Double?,
        hasDDCService: Bool
    ) -> Bool {
        if isBuiltIn {
            return control == .brightness && appleBrightness != nil
        }
        return ddcValue != nil || storedValue != nil
    }

    private nonisolated static func onlineDisplayIDs() -> [CGDirectDisplayID] {
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(UInt32(ids.count), &ids, &count) == .success else {
            return []
        }
        return Array(ids.prefix(Int(count)))
    }

    /// 读取显示器名称。
    ///
    /// 该函数每 5 秒被刷新流程调用一次，因此 CoreDisplay 的 Create 规则字典
    /// 必须在这里被取走所有权并释放，否则每次刷新都会泄漏一个字典（#865）。
    /// 可见性为 internal，便于测试直接覆盖这条路径。
    nonisolated static func displayName(for id: CGDirectDisplayID, isBuiltIn: Bool) -> String {
        if let createInfoDictionary = PrivateDisplaySymbol.coreDisplayCreateInfoDictionary,
           let unmanagedInfo = createInfoDictionary(id)
        {
            // Create 规则返回 +1 持有的字典，必须在这里取走所有权并释放，
            // 否则每次刷新都会泄漏一个字典（#865）。
            let info = unmanagedInfo.takeRetainedValue() as? [String: Any]
            if let localizedNames = info?["DisplayProductName"] as? [String: String] {
                let name = localizedNames[Locale.current.identifier]
                    ?? localizedNames["en_US"]
                    ?? localizedNames.first?.value
                if let name { return name }
            }
        }

        if isBuiltIn { return "Built-in Display" }

        let model = CGDisplayModelNumber(id)
        return model == 0 ? "External Display" : "External Display \(model)"
    }

    private nonisolated static func displayStorageID(
        for id: CGDirectDisplayID,
        name: String,
        isBuiltIn: Bool
    ) -> String {
        let vendor = CGDisplayVendorNumber(id)
        let model = CGDisplayModelNumber(id)
        let serial = CGDisplaySerialNumber(id)
        let role = isBuiltIn ? "builtIn" : "external"
        let sanitizedName = name
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        return "\(role).\(sanitizedName).\(vendor).\(model).\(serial)"
    }

    // MARK: - Persistence

    private nonisolated static func storedValue(
        for control: DisplayControlKind,
        displayStorageID: String,
        store: DisplayControlPluginLocalStore
    ) -> Double? {
        let key = storedValueKey(for: control, displayStorageID: displayStorageID)
        guard store.contains(key) else { return nil }
        guard let value = store.double(forKey: key) else { return nil }
        return min(100, max(0, value))
    }

    private nonisolated static func saveStoredValue(
        _ value: Double,
        for control: DisplayControlKind,
        displayStorageID: String,
        store: DisplayControlPluginLocalStore
    ) {
        store.set(
            min(100, max(0, value)),
            forKey: storedValueKey(for: control, displayStorageID: displayStorageID)
        )
    }

    private nonisolated static func removeStoredValue(
        for control: DisplayControlKind,
        displayStorageID: String,
        store: DisplayControlPluginLocalStore
    ) {
        store.removeObject(forKey: storedValueKey(for: control, displayStorageID: displayStorageID))
    }

    private nonisolated static func storedValueKey(
        for control: DisplayControlKind,
        displayStorageID: String
    ) -> String {
        "displayControl.value.\(displayStorageID).\(control.storageKey)"
    }
}
