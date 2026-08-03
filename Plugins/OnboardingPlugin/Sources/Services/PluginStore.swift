import Foundation
import LumiKernel
import os
import SuperLogKit

// MARK: - Store

public final class PluginStore: SuperLog {
    // MARK: - 属性

    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.onboarding.store")
    private let fileManager = FileManager.default
    private let settingsURL: URL
    private let stateFileURL: URL
    private let corruptStateFileURL: URL

    // MARK: - 初始化

    public init(pluginId: String) {
        let pluginDirectory = RuntimeBridge.pluginDirectory
            ?? RuntimeBridge.fallbackRootDirectory
                .appendingPathComponent(pluginId, isDirectory: true)
        self.settingsURL = pluginDirectory.appendingPathComponent("settings", isDirectory: true)
        self.stateFileURL = settingsURL.appendingPathComponent("onboarding_state.plist")
        self.corruptStateFileURL = settingsURL.appendingPathComponent("onboarding_state.corrupt.plist")
        prepareDirectories()
    }

    init(settingsDirectory: URL) {
        self.settingsURL = settingsDirectory
        self.stateFileURL = settingsURL.appendingPathComponent("onboarding_state.plist")
        self.corruptStateFileURL = settingsURL.appendingPathComponent("onboarding_state.corrupt.plist")
        prepareDirectories()
    }

    // MARK: - 公开方法

    public var completed: Bool {
        get { readCompletedFlag() }
        set { setCompleted(newValue) }
    }

    @discardableResult
    public func setCompleted(_ completed: Bool) -> Bool {
        writeCompletedFlag(completed)
    }

    // MARK: - 私有方法

    private func prepareDirectories() {
        do {
            try fileManager.createDirectory(at: settingsURL, withIntermediateDirectories: true)
        } catch {
            Self.logger.error("\(Self.t)Create onboarding settings directory failed: \(error.localizedDescription)")
        }
    }

    private func readCompletedFlag() -> Bool {
        guard fileManager.fileExists(atPath: stateFileURL.path) else {
            return false
        }

        do {
            let data = try Data(contentsOf: stateFileURL)
            let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            guard let dict = plist as? [String: Any] else {
                Self.logger.error("\(Self.t)Read onboarding state failed: root plist is not a dictionary")
                quarantineCorruptState()
                return false
            }
            return dict["completed"] as? Bool ?? false
        } catch {
            Self.logger.error("\(Self.t)Read onboarding state failed: \(error.localizedDescription)")
            quarantineCorruptState()
            return false
        }
    }

    @discardableResult
    private func writeCompletedFlag(_ completed: Bool) -> Bool {
        let payload: [String: Any] = [
            "completed": completed,
            "updatedAt": Date()
        ]

        let data: Data
        do {
            data = try PropertyListSerialization.data(fromPropertyList: payload, format: .binary, options: 0)
        } catch {
            Self.logger.error("\(Self.t)Encode onboarding state failed: \(error.localizedDescription)")
            return false
        }

        let tempURL = settingsURL.appendingPathComponent("onboarding_state.tmp")
        do {
            try fileManager.createDirectory(at: settingsURL, withIntermediateDirectories: true)
            try data.write(to: tempURL, options: .atomic)
            if fileManager.fileExists(atPath: stateFileURL.path) {
                _ = try fileManager.replaceItemAt(stateFileURL, withItemAt: tempURL)
            } else {
                try fileManager.moveItem(at: tempURL, to: stateFileURL)
            }
            return true
        } catch {
            Self.logger.error("\(Self.t)Persist onboarding state failed: \(error.localizedDescription)")
            try? fileManager.removeItem(at: tempURL)
            return false
        }
    }

    private func quarantineCorruptState() {
        guard fileManager.fileExists(atPath: stateFileURL.path) else { return }

        do {
            if fileManager.fileExists(atPath: corruptStateFileURL.path) {
                try fileManager.removeItem(at: corruptStateFileURL)
            }
            try fileManager.moveItem(at: stateFileURL, to: corruptStateFileURL)
        } catch {
            Self.logger.error("\(Self.t)Quarantine corrupt onboarding state failed: \(error.localizedDescription)")
        }
    }
}
