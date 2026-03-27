import SwiftUI

// MARK: - Progress Model

struct RAGIndexProgressEvent: Sendable {
    let projectPath: String
    let scannedFiles: Int
    let totalFiles: Int
    let indexedFiles: Int
    let skippedFiles: Int
    let chunkCount: Int
    let currentFilePath: String
    let isFinished: Bool
}

// MARK: - Notification Extension

extension Notification.Name {
    /// RAG 索引进度通知
    /// object: nil
    /// userInfo:
    /// - projectPath: String
    /// - scannedFiles: Int
    /// - totalFiles: Int
    /// - indexedFiles: Int
    /// - skippedFiles: Int
    /// - chunkCount: Int
    /// - currentFilePath: String
    /// - isFinished: Bool
    static let ragIndexProgressDidChange = Notification.Name("RAG.IndexProgressDidChange")
}

// MARK: - NotificationCenter Extension

extension NotificationCenter {
    static func postRAGIndexProgress(_ event: RAGIndexProgressEvent) {
        NotificationCenter.default.post(
            name: .ragIndexProgressDidChange,
            object: nil,
            userInfo: [
                "projectPath": event.projectPath,
                "scannedFiles": event.scannedFiles,
                "totalFiles": event.totalFiles,
                "indexedFiles": event.indexedFiles,
                "skippedFiles": event.skippedFiles,
                "chunkCount": event.chunkCount,
                "currentFilePath": event.currentFilePath,
                "isFinished": event.isFinished
            ]
        )
    }
}

// MARK: - View Extension

extension View {
    func onRAGIndexProgressDidChange(
        perform action: @escaping (RAGIndexProgressEvent) -> Void
    ) -> some View {
        onReceive(
            NotificationCenter.default
                .publisher(for: .ragIndexProgressDidChange)
                .receive(on: RunLoop.main)
        ) { notification in
            guard
                let userInfo = notification.userInfo,
                let projectPath = userInfo["projectPath"] as? String,
                let scannedFiles = userInfo["scannedFiles"] as? Int,
                let totalFiles = userInfo["totalFiles"] as? Int,
                let indexedFiles = userInfo["indexedFiles"] as? Int,
                let skippedFiles = userInfo["skippedFiles"] as? Int,
                let chunkCount = userInfo["chunkCount"] as? Int,
                let currentFilePath = userInfo["currentFilePath"] as? String,
                let isFinished = userInfo["isFinished"] as? Bool
            else {
                return
            }

            action(
                RAGIndexProgressEvent(
                    projectPath: projectPath,
                    scannedFiles: scannedFiles,
                    totalFiles: totalFiles,
                    indexedFiles: indexedFiles,
                    skippedFiles: skippedFiles,
                    chunkCount: chunkCount,
                    currentFilePath: currentFilePath,
                    isFinished: isFinished
                )
            )
        }
    }
}

