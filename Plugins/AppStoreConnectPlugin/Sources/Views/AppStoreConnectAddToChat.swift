import Foundation
import SwiftUI

@MainActor
enum AppStoreConnectAddToChat {
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
            lines.append("Task: Analyze this selected App Store Connect object and suggest the next best actions.")
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
    @State private var isHovering = false
    @State private var currentProjectPath = ""

    func body(content: Content) -> some View {
        content
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovering ? Color.accentColor.opacity(0.08) : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isHovering ? Color.accentColor.opacity(0.45) : .clear, lineWidth: 1)
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.12)) {
                    isHovering = hovering
                }
            }
            .onAppear {
                if let provider = AppStoreConnectAddToChat.currentProjectPathProvider {
                    currentProjectPath = provider()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: AppStoreConnectAddToChat.projectPathDidChangeNotification)) { notification in
                if let path = notification.userInfo?[AppStoreConnectAddToChat.projectPathUserInfoKey] as? String {
                    currentProjectPath = path
                }
            }
            .contextMenu {
                Button(AppStoreConnectLocalization.string("添加到对话")) {
                    AppStoreConnectAddToChat.post(
                        entityType: entityType,
                        entityID: entityID,
                        title: title,
                        sourceView: sourceView,
                        fields: fields,
                        mode: .reference
                    )
                }
                Button(AppStoreConnectLocalization.string("添加到对话并分析")) {
                    AppStoreConnectAddToChat.post(
                        entityType: entityType,
                        entityID: entityID,
                        title: title,
                        sourceView: sourceView,
                        fields: fields,
                        mode: .analyze
                    )
                }
                if isLumiProject {
                    Divider()
                    Button(AppStoreConnectLocalization.string("添加开发上下文到对话")) {
                        AppStoreConnectAddToChat.post(
                            entityType: entityType,
                            entityID: entityID,
                            title: title,
                            sourceView: sourceView,
                            fields: fields,
                            mode: .devReference
                        )
                    }
                    Button(AppStoreConnectLocalization.string("添加开发上下文并分析")) {
                        AppStoreConnectAddToChat.post(
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
    }

    private var isLumiProject: Bool {
        let trimmed = currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let url = URL(fileURLWithPath: trimmed)
        let markerURL = url.appendingPathComponent(".lumi-project", isDirectory: false)
        return FileManager.default.fileExists(atPath: markerURL.path)
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
