import CoreGraphics
import Foundation
import os

private let displayLog = Logger(subsystem: "com.coffic.lumi", category: "plugin.display-control.display")

// MARK: - DisplayServices Bridge (built-in display)

private final class DisplayServicesBridge: Sendable {
    func getBrightness(displayID: CGDirectDisplayID) -> Float? {
        var value: Float = -1
        let result = _DisplayServicesGetBrightness(displayID, &value)
        guard result == 0, value >= 0 else { return nil }
        return min(1, max(0, value))
    }

    func setBrightness(displayID: CGDirectDisplayID, value: Float) -> Bool {
        let clampedValue = min(1, max(0, value))
        return _DisplayServicesSetBrightness(displayID, clampedValue) == 0
    }
}

// MARK: - DisplayService

@MainActor
final class DisplayService: ObservableObject {
    static let shared = DisplayService()

    @Published private(set) var displays: [ControlledDisplay] = []
    @Published private var pendingValues: [CGDirectDisplayID: [DisplayControlKind: Double]] = [:]

    private let ddc = DisplayDDCBridge()
    private let displayServicesBridge = DisplayServicesBridge()
    private let defaults = UserDefaults.standard
    private var fallbackValues: [CGDirectDisplayID: [DisplayControlKind: Double]] = [:]

    // Debounce
    private var debounceTimers: [ControlKey: Task<Void, Never>] = [:]

    private init() {}

    // MARK: - Refresh

    func refresh() {
        let ddc = self.ddc
        let displayServicesBridge = self.displayServicesBridge
        let defaults = self.defaults

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
                let storedBrightness = Self.storedValue(for: .brightness, displayStorageID: storageID, defaults: defaults)
                let storedVolume = Self.storedValue(for: .volume, displayStorageID: storageID, defaults: defaults)
                let storedContrast = Self.storedValue(for: .contrast, displayStorageID: storageID, defaults: defaults)

                let display = ControlledDisplay(
                    id: id,
                    storageID: storageID,
                    name: name,
                    isBuiltIn: isBuiltIn,
                    supportsBrightness: isBuiltIn
                        ? appleBrightness != nil
                        : (ddcBrightness != nil || storedBrightness != nil || hasDDCService),
                    supportsVolume: !isBuiltIn && (ddcVolume != nil || storedVolume != nil || hasDDCService),
                    supportsContrast: !isBuiltIn && (ddcContrast != nil || storedContrast != nil || hasDDCService),
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
                    defaults: defaults
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
                Self.saveStoredValue(value, for: control, displayStorageID: display.storageID, defaults: defaults)
            }
            updateLocalValue(value, for: control, displayID: key.displayID)
            fallbackValues[key.displayID, default: [:]][key.control] = value
        } else {
            // DDC writes can fail transiently (busy bus, monitor OSD, etc.).
            // Keep the control enabled and persist the desired value locally.
            if !display.isBuiltIn {
                Self.saveStoredValue(value, for: control, displayStorageID: display.storageID, defaults: defaults)
            }
            updateLocalValue(value, for: control, displayID: key.displayID)
            fallbackValues[key.displayID, default: [:]][key.control] = value
            displayLog.warning(
                "Display control write failed for \(control.storageKey, privacy: .public) on display \(displayID, privacy: .public)"
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

    private nonisolated static func onlineDisplayIDs() -> [CGDirectDisplayID] {
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(UInt32(ids.count), &ids, &count) == .success else {
            return []
        }
        return Array(ids.prefix(Int(count)))
    }

    private nonisolated static func displayName(for id: CGDirectDisplayID, isBuiltIn: Bool) -> String {
        if let rawInfo = _CoreDisplay_DisplayCreateInfoDictionary(id),
           let info = rawInfo as? [String: Any],
           let localizedNames = info["DisplayProductName"] as? [String: String]
        {
            let name = localizedNames[Locale.current.identifier]
                ?? localizedNames["en_US"]
                ?? localizedNames.first?.value
            if let name { return name }
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

    // MARK: - UserDefaults Persistence (static for Sendable safety)

    private nonisolated static func storedValue(
        for control: DisplayControlKind,
        displayStorageID: String,
        defaults: UserDefaults
    ) -> Double? {
        let key = storedValueKey(for: control, displayStorageID: displayStorageID)
        guard defaults.object(forKey: key) != nil else { return nil }
        return min(100, max(0, defaults.double(forKey: key)))
    }

    private nonisolated static func saveStoredValue(
        _ value: Double,
        for control: DisplayControlKind,
        displayStorageID: String,
        defaults: UserDefaults
    ) {
        defaults.set(
            min(100, max(0, value)),
            forKey: storedValueKey(for: control, displayStorageID: displayStorageID)
        )
    }

    private nonisolated static func removeStoredValue(
        for control: DisplayControlKind,
        displayStorageID: String,
        defaults: UserDefaults
    ) {
        defaults.removeObject(
            forKey: storedValueKey(for: control, displayStorageID: displayStorageID)
        )
    }

    private nonisolated static func storedValueKey(
        for control: DisplayControlKind,
        displayStorageID: String
    ) -> String {
        "displayControl.value.\(displayStorageID).\(control.storageKey)"
    }
}
