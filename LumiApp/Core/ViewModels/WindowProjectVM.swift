import AppKit
import Foundation
import SwiftUI

/// 项目管理 ViewModel
///
/// ## 初始化规则
///
/// 由 `WindowContainer` 持有，通过 `.environmentObject()` 注入。nView 通过 `@EnvironmentObject var projectVM: WindowProjectVM` 访问。n每个窗口有独立的当前项目状态。
/// 负责管理项目状态、文件选择和项目配置
///
/// ## 初始化规则
///
/// 由 `WindowContainer` 持有并通过 `.environmentObject()` 注入。
/// View 通过 `@EnvironmentObject var projectVM: WindowProjectVM` 访问。
/// 每个窗口有独立的当前项目状态。
@MainActor
final class WindowProjectVM: ObservableObject, SuperLog {
    nonisolated static let emoji = "📁"
    nonisolated static let verbose: Bool = false
    @Published private(set) var currentProject: Project? = nil

    /// 当前代码选区范围（包含文件路径和行列号，不含具体内容）
    @Published private(set) var codeSelectionRange: CodeSelectionRange?

    // 语言偏好
    @Published var languagePreference: LanguagePreference = .chinese

    /// 当前项目名称
    var currentProjectName: String {
        self.currentProject?.name ?? ""
    }

    /// 当前项目路径
    var currentProjectPath: String {
        self.currentProject?.path ?? ""
    }

    /// 是否已选择项目
    var isProjectSelected: Bool {
        self.currentProject != nil
    }

    private let contextService: ContextService
    private let llmService: LLMService

    /// 初始化 WindowProjectVM
    /// - Parameters:
    ///   - contextService: 上下文服务（必须由外部传入）
    ///   - llmService: LLM 服务（必须由外部传入，不允许自行创建）
    init(contextService: ContextService, llmService: LLMService) {
        self.contextService = contextService
        self.llmService = llmService
    }

    /// 清除当前项目，恢复到未选择任何项目的状态
    func clearProject() {
        currentProject = nil
        codeSelectionRange = nil

        Task {
            await contextService.setProjectRoot(nil)
        }

        if Self.verbose {
            AppLogger.core.info("\(Self.t)📁 已清除当前项目")
        }
    }

    /// 切换到指定项目
    /// - Parameters:
    ///   - project: 目标项目
    ///   - reason: 触发本次切换的原因（用于日志追踪）
    func switchProject(to project: Project, reason: String) {
        if currentProject?.path == project.path {
            if Self.verbose {
                AppLogger.core.info("\(Self.t)⚠️ 项目已是当前项目，跳过: \(project.path), reason: \(reason)")
            }
            return
        }

        currentProject = project
        codeSelectionRange = nil
        AppLogger.core.info("\(Self.t)切换项目: \(project.name) (\(project.path)), reason: \(reason)")
    }

    /// 将指定文件或目录移到废纸篓
    /// - Parameter url: 目标文件或目录路径
    func deleteItem(at url: URL) {
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            if Self.verbose {
                AppLogger.core.info("\(Self.t)🗑️ 已移到废纸篓：\(url.lastPathComponent)")
            }
        } catch {
            AppLogger.core.error("\(Self.t)❌ 移到废纸篓失败：\(error.localizedDescription)")
        }
    }

    /// 更新代码选区范围
    /// - Parameter range: 选区范围信息，传 nil 表示清除选区
    func updateCodeSelection(_ range: CodeSelectionRange?) {
        codeSelectionRange = range

        if Self.verbose {
            if let range = range {
                AppLogger.core.info("\(Self.t)📍 代码选区已更新：\(range.description)")
            } else {
                AppLogger.core.info("\(Self.t)📍 代码选区已清除")
            }
        }
    }

    func setLanguagePreference(_ preference: LanguagePreference) {
        self.languagePreference = preference
    }
}
