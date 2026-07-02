import Foundation
import SwiftUI

// MARK: - LumiCore 配置

/// LumiCore 配置
public struct LumiCoreConfiguration: Sendable {
    public let dataRootDirectory: URL

    public init(dataRootDirectory: URL) {
        self.dataRootDirectory = dataRootDirectory
    }
}

// MARK: - LumiCore 主入口

@MainActor
public enum LumiCore {
    private static var configuration: LumiCoreConfiguration?

    // MARK: - 配置

    public static func configure(dataRootDirectory: URL) {
        let directory = dataRootDirectory.standardizedFileURL
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        configuration = LumiCoreConfiguration(dataRootDirectory: directory)
    }

    public static var dataRootDirectory: URL {
        guard let configuration else {
            fatalError("LumiCore.configure(dataRootDirectory:) must be called before using LumiCore storage APIs.")
        }

        return configuration.dataRootDirectory
    }

    public static var coreDataDirectory: URL {
        directory(named: "Core", under: dataRootDirectory)
    }

    public static func pluginDataDirectory(for pluginName: String) -> URL {
        directory(named: sanitizeDirectoryName(pluginName, fallback: "Plugin"), under: dataRootDirectory)
    }

    private static func directory(named name: String, under root: URL) -> URL {
        let directory = root.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        return directory
    }

    private static func sanitizeDirectoryName(_ name: String, fallback: String) -> String {
        let sanitized = name.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "_")

        return sanitized.isEmpty ? fallback : sanitized
    }

    // MARK: - Logo 模块
    
    /// Logo 显示场景
    /// 详细实现见 Sources/Internal/Logo/LogoScene.swift
    public enum LogoScene: String, CaseIterable, Sendable {
        case general
        case appIcon
        case about
        /// 系统菜单栏图标：恒为单色模板图（由系统统一着色），无动画。
        case statusBar
        case custom
    }

    /// 插件贡献的 Logo 项
    /// 详细实现见 Sources/Internal/Logo/LumiLogoItem.swift
    public struct LogoItem: Identifiable, Sendable {
        public let id: String
        public let order: Int
        public let makeView: @MainActor (LogoScene) -> AnyView
        public let makeOverlay: (@MainActor (LogoScene) -> AnyView)?

        public init<V: View>(
            id: String,
            order: Int,
            @ViewBuilder makeView: @escaping @MainActor (LogoScene) -> V
        ) {
            self.id = id
            self.order = order
            self.makeView = { scene in AnyView(makeView(scene)) }
            self.makeOverlay = nil
        }

        public init<V: View, O: View>(
            id: String,
            order: Int,
            @ViewBuilder makeView: @escaping @MainActor (LogoScene) -> V,
            @ViewBuilder makeOverlay: @escaping @MainActor (LogoScene) -> O
        ) {
            self.id = id
            self.order = order
            self.makeView = { scene in AnyView(makeView(scene)) }
            self.makeOverlay = { scene in AnyView(makeOverlay(scene)) }
        }
    }
    
    /// Logo 注册表
    /// 详细实现见 Sources/Internal/Logo/LogoRegistry.swift
    @MainActor
    public final class LogoRegistry: ObservableObject {
        public static let shared = LogoRegistry()

        @Published private(set) public var bestItem: LogoItem?

        private init() {}

        public func register(_ items: [LogoItem]) {
            let newBest = items.max(by: { $0.order < $1.order })
            Task { @MainActor [weak self] in
                self?.bestItem = newBest
            }
        }
    }
}

// MARK: - 版本信息

public enum LumiCoreKit {
    public static let version = "1.0.0"
}
