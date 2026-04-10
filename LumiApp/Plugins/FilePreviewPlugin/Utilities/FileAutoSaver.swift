import Foundation
import SwiftUI

/// 文件自动保存状态
enum FileSaveState: Equatable {
    case idle           // 空闲状态（未修改或已保存）
    case pending       // 待保存（有修改，等待防抖）
    case saving        // 保存中
    case saved         // 已保存
    case error(String) // 保存失败

    var icon: String {
        switch self {
        case .idle:
            return "checkmark.circle"
        case .pending:
            return "pencil.circle"
        case .saving:
            return "arrow.triangle.2.circlepath"
        case .saved:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .idle:
            return AppUI.Color.semantic.textTertiary
        case .pending:
            return AppUI.Color.semantic.textSecondary
        case .saving:
            return AppUI.Color.semantic.primary
        case .saved:
            return AppUI.Color.semantic.success
        case .error:
            return AppUI.Color.semantic.error
        }
    }

    var message: String {
        switch self {
        case .idle:
            return String(localized: "No Changes", table: "FilePreview")
        case .pending:
            return String(localized: "Editing...", table: "FilePreview")
        case .saving:
            return String(localized: "Saving...", table: "FilePreview")
        case .saved:
            return String(localized: "Saved", table: "FilePreview")
        case .error(let msg):
            return msg
        }
    }
}

/// 文件自动保存管理器
@MainActor
final class FileAutoSaver: ObservableObject {
    /// 当前保存状态
    @Published private(set) var state: FileSaveState = .idle

    /// 防抖延迟时间（秒）
    static let debounceDelay: TimeInterval = 1.5

    /// 成功状态显示时间（秒）
    static let successDisplayDuration: TimeInterval = 2.0

    /// 当前防抖任务
    private var debounceTask: Task<Void, Never>?

    /// 成功状态清除任务
    private var successClearTask: Task<Void, Never>?

    /// 当前正在保存的文件 URL
    private var currentFileURL: URL?

    /// 保存文件内容
    /// - Parameters:
    ///   - content: 要保存的内容
    ///   - url: 文件 URL
    ///   - immediate: 是否立即保存（跳过防抖）
    func save(content: String, to url: URL, immediate: Bool = false) {
        // 取消之前的防抖任务
        debounceTask?.cancel()
        debounceTask = nil

        // 取消成功状态清除任务
        successClearTask?.cancel()
        successClearTask = nil

        // 如果内容为空或文件是只读的，不保存
        guard !content.isEmpty else {
            state = .idle
            return
        }

        // 标记为待保存状态
        state = .pending
        currentFileURL = url

        if immediate {
            performSave(content: content, to: url)
        } else {
            // 防抖保存
            debounceTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(Self.debounceDelay))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self?.performSave(content: content, to: url)
                }
            }
        }
    }

    /// 立即保存当前待保存的内容
    func flush() {
        debounceTask?.cancel()
        debounceTask = nil
        // 注意：flush 时应该由外部提供 content 和 url
        // 这里只是取消防抖，实际保存由外部处理
    }

    /// 重置状态（切换文件时调用）
    func reset() {
        debounceTask?.cancel()
        debounceTask = nil
        successClearTask?.cancel()
        successClearTask = nil
        currentFileURL = nil
        state = .idle
    }

    /// 执行实际的文件保存
    private func performSave(content: String, to url: URL) {
        state = .saving

        // 捕获必要的值，避免捕获 self
        let successState: FileSaveState = .saved
        let notFoundError = String(localized: "File not found", table: "FilePreview")

        Task.detached(priority: .userInitiated) {
            do {
                // 检查文件是否存在
                guard FileManager.default.fileExists(atPath: url.path) else {
                    await MainActor.run { [notFoundError] in
                        self.state = .error(notFoundError)
                    }
                    return
                }

                // 尝试写入文件
                try content.write(to: url, atomically: true, encoding: .utf8)

                await MainActor.run {
                    self.state = successState
                    self.scheduleSuccessClear()
                }
            } catch {
                let errorMessage = String(
                    localized: "Save failed: \(error.localizedDescription)",
                    table: "FilePreview"
                )
                await MainActor.run {
                    self.state = .error(errorMessage)
                    self.scheduleSuccessClear()
                }
            }
        }
    }

    /// 安排成功状态清除任务
    private func scheduleSuccessClear() {
        successClearTask?.cancel()
        successClearTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.successDisplayDuration))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if case .saved = self?.state {
                    self?.state = .idle
                }
            }
        }
    }
}