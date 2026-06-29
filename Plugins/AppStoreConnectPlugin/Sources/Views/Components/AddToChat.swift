import Foundation
import SwiftUI

@MainActor
enum AddToChat {
    private static let notificationName = Notification.Name("addToChat")
    fileprivate static let projectPathDidChangeNotification = Notification.Name("lumi.currentProjectPathDidChange")
    fileprivate static let projectPathUserInfoKey = "path"
    private static var lastPostedAtByKey: [String: Date] = [:]
    private static let dedupeInterval: TimeInterval = 1.5
    static var currentProjectPathProvider: (@MainActor () -> String)?

    enum PostMode: String {
        case reference
        case analyze
        case devReference
        case devAnalyze
    }

    static func post(
        entityType: String,
        entityID: String,
        title: String,
        sourceView: String,
        fields: [String: String] = [:],
        mode: PostMode = .reference
    ) {
        let key = "\(mode.rawValue)|\(entityType)|\(entityID)|\(sourceView)"
        let now = Date()
        if let last = lastPostedAtByKey[key], now.timeIntervalSince(last) < dedupeInterval {
            return
        }
        lastPostedAtByKey[key] = now

        var lines: [String] = [
            "[AppStoreConnect Context]",
            "entityType: \(entityType)",
            "entityID: \(entityID)",
            "displayName: \(title)",
            "sourceView: \(sourceView)"
        ]

        if !fields.isEmpty {
            let fieldText = fields
                .sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: ", ")
            lines.append("fields: {\(fieldText)}")
        }

        if mode == .analyze {
            lines.append("")
            if entityType == "coverArtDocument" {
                lines.append(
                    "Task: Review this responsive HTML cover art document and iterate on index.html using app-store-connect.read-cover-art and app-store-connect.update-cover-art. Keep layouts working across all previewDisplayTypes for the deviceFamily."
                )
            } else {
                lines.append("Task: Analyze this selected App Store Connect object and suggest the next best actions.")
            }
        } else if mode == .devReference || mode == .devAnalyze {
            lines.append("")
            lines.append("[Development Context]")
            lines.append("targetArea: \(sourceView)")
            lines.append("intent: UI/code refinement")
            if mode == .devAnalyze {
                lines.append("Task: Locate related SwiftUI code for this UI area and propose an implementation patch.")
            }
        }

        NotificationCenter.default.post(
            name: notificationName,
            object: nil,
            userInfo: ["text": lines.joined(separator: "\n")]
        )
    }
}

private struct AppStoreConnectAddToChatModifier: ViewModifier {
    let entityType: String
    let entityID: String
    let title: String
    let sourceView: String
    let fields: [String: String]
    @State private var currentProjectPath = ""
    @State private var isLumiProjectCached = false
    @State private var downloadErrorMessage: String?

    func body(content: Content) -> some View {
        content
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .onAppear {
                if let provider = AddToChat.currentProjectPathProvider {
                    currentProjectPath = provider()
                }
                refreshLumiProjectGate()
            }
            .onReceive(NotificationCenter.default.publisher(for: AddToChat.projectPathDidChangeNotification)) { notification in
                if let path = notification.userInfo?[AddToChat.projectPathUserInfoKey] as? String {
                    currentProjectPath = path
                    refreshLumiProjectGate()
                }
            }
            .contextMenu {
                Button(AppStoreConnectLocalization.string("Add to Chat")) {
                    AddToChat.post(
                        entityType: entityType,
                        entityID: entityID,
                        title: title,
                        sourceView: sourceView,
                        fields: fields,
                        mode: .reference
                    )
                }
                Button(AppStoreConnectLocalization.string("Add to Chat and Analyze")) {
                    AddToChat.post(
                        entityType: entityType,
                        entityID: entityID,
                        title: title,
                        sourceView: sourceView,
                        fields: fields,
                        mode: .analyze
                    )
                }
                if let urlString = fields["previewURL"], !urlString.isEmpty, urlString != "-", let url = URL(string: urlString) {
                    Divider()
                    Button(AppStoreConnectLocalization.string("在浏览器打开图片")) {
                        NSWorkspace.shared.open(url)
                    }
                    Button(AppStoreConnectLocalization.string("下载图片到下载目录")) {
                        Task { await downloadImageToDownloads(from: url) }
                    }
                }
                if isLumiProjectCached {
                    Divider()
                    Button(AppStoreConnectLocalization.string("Add Dev Context to Chat")) {
                        AddToChat.post(
                            entityType: entityType,
                            entityID: entityID,
                            title: title,
                            sourceView: sourceView,
                            fields: fields,
                            mode: .devReference
                        )
                    }
                    Button(AppStoreConnectLocalization.string("Add Dev Context and Analyze")) {
                        AddToChat.post(
                            entityType: entityType,
                            entityID: entityID,
                            title: title,
                            sourceView: sourceView,
                            fields: fields,
                            mode: .devAnalyze
                        )
                    }
                }
            }
            .alert(
                AppStoreConnectLocalization.string("Download Failed"),
                isPresented: Binding(
                    get: { downloadErrorMessage != nil },
                    set: { isPresented in
                        if !isPresented { downloadErrorMessage = nil }
                    }
                )
            ) {
                Button(AppStoreConnectLocalization.string("OK"), role: .cancel) {}
            } message: {
                Text(downloadErrorMessage ?? "")
            }
    }

    private func refreshLumiProjectGate() {
        isLumiProjectCached = evaluateLumiProject()
    }

    private func evaluateLumiProject() -> Bool {
        let effectiveProjectPath: String = {
            if !currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return currentProjectPath
            }
            // In case this modifier instance hasn't received onAppear yet,
            // fallback to provider immediately to avoid gating-by-empty-path.
            return AddToChat.currentProjectPathProvider?() ?? ""
        }()
        return evaluateLumiProject(from: effectiveProjectPath)
    }

    private func evaluateLumiProject(from path: String) -> Bool {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let fileManager = FileManager.default
        let baseURL = URL(fileURLWithPath: trimmed)
        var currentURL = baseURL.standardizedFileURL

        // currentProjectPath can point to a nested workspace directory instead of repo root.
        // Walk up parent directories to find the Lumi marker file.
        for _ in 0..<12 {
            let markerURL = currentURL.appendingPathComponent(".lumi-project", isDirectory: false)
            if fileManager.fileExists(atPath: markerURL.path) {
                return true
            }

            let parentURL = currentURL.deletingLastPathComponent()
            if parentURL.path == currentURL.path {
                break
            }
            currentURL = parentURL
        }
        return false
    }

    private func downloadImageToDownloads(from url: URL) async {
        do {
            let data = try await ScreenshotImageCache.shared.data(for: url, screenshotID: entityID)
            let savedURL = try saveToDownloads(data: data, sourceURL: url)
            NSWorkspace.shared.activateFileViewerSelecting([savedURL])
        } catch {
            downloadErrorMessage = error.localizedDescription
        }
    }

    private func saveToDownloads(data: Data, sourceURL: URL) throws -> URL {
        let fileManager = FileManager.default
        let downloadsDirectory = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads", isDirectory: true)
        try fileManager.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)

        let baseName = sourceURL.deletingPathExtension().lastPathComponent.isEmpty
            ? "app-store-connect-screenshot"
            : sourceURL.deletingPathExtension().lastPathComponent
        let ext = sourceURL.pathExtension.isEmpty ? "png" : sourceURL.pathExtension

        var candidate = downloadsDirectory.appendingPathComponent("\(baseName).\(ext)", isDirectory: false)
        var index = 1
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = downloadsDirectory.appendingPathComponent("\(baseName)-\(index).\(ext)", isDirectory: false)
            index += 1
        }

        try data.write(to: candidate, options: .atomic)
        return candidate
    }
}

extension View {
    func appStoreConnectAddToChatMenu(
        entityType: String,
        entityID: String,
        title: String,
        sourceView: String,
        fields: [String: String] = [:],
        file: String = #fileID,
        line: Int = #line
    ) -> some View {
        var enrichedFields = fields
        enrichedFields["dev.fileID"] = file
        enrichedFields["dev.line"] = String(line)
        return modifier(
            AppStoreConnectAddToChatModifier(
                entityType: entityType,
                entityID: entityID,
                title: title,
                sourceView: sourceView,
                fields: enrichedFields
            )
        )
    }
}
