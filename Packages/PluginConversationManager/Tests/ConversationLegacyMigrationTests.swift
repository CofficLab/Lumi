import Foundation
import ProviderConversation
import SwiftData
import Testing
@testable import PluginConversationManager

@MainActor
@Suite(.serialized)
struct ConversationLegacyMigrationTests {
    @Test func readerCopiesLegacyDatabaseMapsFieldsReusesAndReleasesItsSnapshot() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let firstID = UUID()
        let secondID = UUID()
        try writeLegacyDatabase(at: root, conversations: [
            Conversation(
                id: secondID,
                projectId: "/legacy/second",
                title: "Second",
                createdAt: Date(timeIntervalSince1970: 20),
                updatedAt: Date(timeIntervalSince1970: 25),
                providerId: "anthropic",
                model: "claude",
                chatMode: "invalid-mode",
                verbosity: "unknown",
                languagePreference: "xx"
            ),
            Conversation(
                id: firstID,
                projectId: "/legacy/first",
                title: "First",
                preview: "Legacy preview",
                createdAt: Date(timeIntervalSince1970: 10),
                updatedAt: Date(timeIntervalSince1970: 15),
                providerId: "openai",
                model: "gpt-4.1",
                chatMode: "a3",
                verbosity: "v1",
                languagePreference: "en"
            ),
        ])

        let reader = V4ConversationReader(v4DataRootDirectory: root)
        defer { reader.releaseLegacySnapshot() }
        #expect(reader.hasLegacyData())
        let tempDirectory = FileManager.default.temporaryDirectory
        let copiesBefore = try snapshotDirectories(in: tempDirectory)

        let summaries = try reader.fetchLegacyConversations()
        #expect(summaries.map(\.id) == [firstID, secondID])
        #expect(summaries[0].preview == "Legacy preview")
        #expect(summaries[0].providerID == "openai")
        #expect(summaries[0].modelName == "gpt-4.1")
        #expect(summaries[0].automationLevel == .autonomous)
        #expect(summaries[0].verbosity == .brief)
        #expect(summaries[0].language == .english)
        #expect(summaries[0].projectPath == "/legacy/first")
        #expect(summaries[1].automationLevel == nil)
        #expect(summaries[1].verbosity == nil)
        #expect(summaries[1].language == nil)

        let copiesWithSnapshot = try snapshotDirectories(in: tempDirectory)
        #expect(copiesWithSnapshot.count == copiesBefore.count + 1)
        #expect(try reader.fetchLegacyConversations().count == 2)
        #expect(try snapshotDirectories(in: tempDirectory) == copiesWithSnapshot)

        reader.releaseLegacySnapshot()
        reader.releaseLegacySnapshot()
        #expect(try snapshotDirectories(in: tempDirectory) == copiesBefore)
    }

    @Test func readerReportsMissingAndInvalidLegacyDatabases() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let missingReader = V4ConversationReader(v4DataRootDirectory: root)
        #expect(!missingReader.hasLegacyData())
        #expect(throws: V4ConversationReaderError.self) {
            try missingReader.fetchLegacyConversations()
        }
        #expect(!V4ConversationReader(v4DataRootDirectory: nil).hasLegacyData())

        let databaseDirectory = root.appendingPathComponent("Core", isDirectory: true)
        try FileManager.default.createDirectory(at: databaseDirectory, withIntermediateDirectories: true)
        try Data("not a SwiftData database".utf8).write(to: databaseDirectory.appendingPathComponent("Lumi.db"))
        let invalidReader = V4ConversationReader(v4DataRootDirectory: root)
        #expect(invalidReader.hasLegacyData())
        let temporaryDirectory = FileManager.default.temporaryDirectory
        let copiesBeforeRead = try snapshotDirectories(in: temporaryDirectory)
        #expect(throws: V4ConversationReaderError.self) {
            try invalidReader.fetchLegacyConversations()
        }
        invalidReader.releaseLegacySnapshot()
        #expect(try snapshotDirectories(in: temporaryDirectory) == copiesBeforeRead)
    }

    @Test func locatorPrefersProductionAndUsesDebugFallback() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let currentDirectory = root.appendingPathComponent("active", isDirectory: true)
        let parentDirectory = currentDirectory.deletingLastPathComponent()
        let productionDirectory = parentDirectory.appendingPathComponent("db_production_v4", isDirectory: true)
        let debugDirectory = parentDirectory.appendingPathComponent("db_debug_v4", isDirectory: true)
        try FileManager.default.createDirectory(at: productionDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: debugDirectory, withIntermediateDirectories: true)

        #expect(V4DataDirectoryLocator.locate(currentDataRootDirectory: currentDirectory) == productionDirectory)
        try FileManager.default.removeItem(at: productionDirectory)
        #if DEBUG
        #expect(V4DataDirectoryLocator.locate(currentDataRootDirectory: currentDirectory) == debugDirectory)
        #else
        #expect(V4DataDirectoryLocator.locate(currentDataRootDirectory: currentDirectory) == nil)
        #endif
        try FileManager.default.removeItem(at: debugDirectory)
        #expect(V4DataDirectoryLocator.locate(currentDataRootDirectory: currentDirectory) == nil)
    }

    @Test func migrationImportsLegacyDataOnceAndPersistsMarker() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let v4Root = root.appendingPathComponent("legacy", isDirectory: true)
        let destinationRoot = root.appendingPathComponent("current", isDirectory: true)
        let conversation = Conversation(
            projectId: "/old/project",
            title: "Imported story",
            preview: "From v4",
            providerId: "openai",
            model: "gpt-4.1",
            chatMode: "a2",
            verbosity: "v3",
            languagePreference: "zh"
        )
        try writeLegacyDatabase(at: v4Root, conversations: [conversation])
        let store = try ConversationStore(databaseRootURL: destinationRoot)
        let progress = ConversationMigrationProgressStore()
        let originalPolicy = ConversationLegacyMigration.policy
        ConversationLegacyMigration.policy = .once
        defer { ConversationLegacyMigration.policy = originalPolicy }

        let migration = ConversationLegacyMigration(
            reader: V4ConversationReader(v4DataRootDirectory: v4Root),
            store: store,
            progress: progress,
            destinationRootURL: destinationRoot
        )
        await migration.run()

        #expect(progress.phase == .completed)
        #expect(progress.readCount == 1)
        #expect(progress.importedCount == 1)
        #expect(await store.conversationCount(projectPath: nil, includingChildConversations: true) == 1)
        let imported = await store.fetchConversation(id: conversation.id)
        #expect(imported?.title == "Imported story")
        #expect(imported?.preview == "From v4")
        #expect(imported?.projectPath == "/old/project")
        #expect(imported?.automationLevel == .build)
        #expect(imported?.verbosity == .detailed)
        #expect(imported?.language == .chinese)

        let markerURL = destinationRoot.appendingPathComponent("migration_state.json")
        let markerData = try Data(contentsOf: markerURL)
        let marker = try #require(JSONSerialization.jsonObject(with: markerData) as? [String: Any])
        #expect(marker["completed"] as? Bool == true)
        #expect(marker["importedCount"] as? Int == 1)
        await migration.run()
        #expect(await store.conversationCount(projectPath: nil, includingChildConversations: true) == 1)
        #expect(progress.importedCount == 1)
    }

    @Test func failedDatabaseReadDoesNotWriteMarkerAndCanRetry() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let v4Root = root.appendingPathComponent("legacy", isDirectory: true)
        let coreDirectory = v4Root.appendingPathComponent("Core", isDirectory: true)
        let destinationRoot = root.appendingPathComponent("current", isDirectory: true)
        try FileManager.default.createDirectory(at: coreDirectory, withIntermediateDirectories: true)
        let databaseURL = coreDirectory.appendingPathComponent("Lumi.db")
        try Data("invalid sqlite bytes".utf8).write(to: databaseURL)
        let store = try ConversationStore(databaseRootURL: destinationRoot)
        let progress = ConversationMigrationProgressStore()
        let originalPolicy = ConversationLegacyMigration.policy
        ConversationLegacyMigration.policy = .once
        defer { ConversationLegacyMigration.policy = originalPolicy }
        let reader = V4ConversationReader(v4DataRootDirectory: v4Root)
        let migration = ConversationLegacyMigration(
            reader: reader,
            store: store,
            progress: progress,
            destinationRootURL: destinationRoot
        )

        await migration.run()
        #expect(progress.phase == .failed)
        #expect(progress.readCount == 0)
        #expect(!FileManager.default.fileExists(atPath: destinationRoot.appendingPathComponent("migration_state.json").path))

        try FileManager.default.removeItem(at: databaseURL)
        let retriedConversation = Conversation(title: "Retry succeeded")
        try writeLegacyDatabase(at: v4Root, conversations: [retriedConversation])
        await migration.run()

        #expect(progress.phase == .completed)
        #expect(progress.readCount == 1)
        #expect(progress.importedCount == 1)
        #expect(await store.fetchConversation(id: retriedConversation.id)?.title == "Retry succeeded")
        #expect(FileManager.default.fileExists(atPath: destinationRoot.appendingPathComponent("migration_state.json").path))
    }

    @Test func emptyLegacyDatabaseCompletesMigrationWithZeroImports() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let v4Root = root.appendingPathComponent("legacy", isDirectory: true)
        let destinationRoot = root.appendingPathComponent("current", isDirectory: true)
        try writeLegacyDatabase(at: v4Root, conversations: [])
        let store = try ConversationStore(databaseRootURL: destinationRoot)
        let progress = ConversationMigrationProgressStore()
        let originalPolicy = ConversationLegacyMigration.policy
        ConversationLegacyMigration.policy = .always
        defer { ConversationLegacyMigration.policy = originalPolicy }

        let migration = ConversationLegacyMigration(
            reader: V4ConversationReader(v4DataRootDirectory: v4Root),
            store: store,
            progress: progress,
            destinationRootURL: destinationRoot
        )
        await migration.run()

        #expect(progress.phase == .completed)
        #expect(progress.readCount == 0)
        #expect(progress.importedCount == 0)
        #expect(FileManager.default.fileExists(atPath: destinationRoot.appendingPathComponent("migration_state.json").path))
    }
}

@MainActor
private func writeLegacyDatabase(at root: URL, conversations: [Conversation]) throws {
    let databaseDirectory = root.appendingPathComponent("Core", isDirectory: true)
    try FileManager.default.createDirectory(at: databaseDirectory, withIntermediateDirectories: true)
    let databaseURL = databaseDirectory.appendingPathComponent("Lumi.db")
    let schema = Schema([Conversation.self])
    let configuration = ModelConfiguration(
        schema: schema,
        url: databaseURL,
        allowsSave: true,
        cloudKitDatabase: .none
    )
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let context = ModelContext(container)
    for conversation in conversations {
        context.insert(conversation)
    }
    try context.save()
}

private func makeTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("PluginConversationMigrationTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

private func snapshotDirectories(in directory: URL) throws -> Set<URL> {
    Set(try FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
    ).filter { $0.lastPathComponent.hasPrefix("lumi_v4_conversation_migration_") })
}
