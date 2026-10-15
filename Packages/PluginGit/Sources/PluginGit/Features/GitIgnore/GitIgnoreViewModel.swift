import Foundation
import SwiftUI

/// .gitignore 编辑面板的视图模型。
@MainActor
public final class GitIgnoreViewModel: ObservableObject {
    @Published public private(set) var rules: [GitIgnoreService.Rule] = []
    @Published public private(set) var exists: Bool = false
    @Published public private(set) var isLoading: Bool = false
    @Published public var draft: String = ""
    @Published public private(set) var lastError: String?
    @Published public private(set) var lastInfo: String?

    public init() {}

    public var projectPath: String = ""

    public func load() async {
        let path = projectPath
        guard !path.isEmpty else { exists = false; rules = []; return }
        isLoading = true
        defer { isLoading = false }
        let snapshot = await Task.detached(priority: .userInitiated) {
            (
                content: GitIgnoreService.read(forProjectAt: path),
                exists:  GitIgnoreService.exists(forProjectAt: path)
            )
        }.value
        exists = snapshot.exists
        let content = snapshot.content ?? ""
        draft = content
        rules = GitIgnoreService.parse(content)
        lastError = nil
    }

    public func save() async {
        do {
            try GitIgnoreService.write(draft, forProjectAt: projectPath)
            rules = GitIgnoreService.parse(draft)
            exists = true
            lastInfo = "Saved .gitignore"
            lastError = nil
        } catch {
            lastError = "Save failed: \(error.localizedDescription)"
        }
    }

    public func insertTemplate(_ name: String) async {
        guard let body = GitIgnoreService.template(name) else { return }
        // 始终在文件末尾追加；空文件时直接覆盖。
        if draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draft = body
        } else {
            // 用空行隔开
            if !draft.hasSuffix("\n") { draft += "\n" }
            draft += "\n" + body
        }
        await save()
    }
}
