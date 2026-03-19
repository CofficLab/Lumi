import Foundation
import SwiftData
import MagicKit

actor AutoTitleGenerationStore: SuperLog {
    nonisolated static let emoji = "🏷️"
    nonisolated static let verbose = false

    nonisolated static let shared = AutoTitleGenerationStore()

    private let container: ModelContainer

    private init() {
        let schema = Schema([
            AutoTitleGenerationRecord.self
        ])

        let dbDir = AppConfig.getDBFolderURL().appendingPathComponent("AgentAutoTitlePlugin", isDirectory: true)
        try? FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)
        let dbURL = dbDir.appendingPathComponent("AgentAutoTitle.sqlite")

        let config = ModelConfiguration(
            schema: schema,
            url: dbURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        do {
            self.container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create AgentAutoTitle ModelContainer: \(error)")
        }
    }

    func hasTriggered(conversationId: UUID) -> Bool {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<AutoTitleGenerationRecord>(
            predicate: #Predicate { $0.conversationId == conversationId }
        )
        return ((try? context.fetch(descriptor).first) != nil)
    }

    func markTriggered(conversationId: UUID) {
        let context = ModelContext(container)
        let record = AutoTitleGenerationRecord(conversationId: conversationId)
        context.insert(record)
        do {
            try context.save()
        } catch {
            if Self.verbose {
                AgentAutoTitlePlugin.logger.error("\(Self.t)❌ 保存触发记录失败：\(error.localizedDescription)")
            }
        }
    }
}
