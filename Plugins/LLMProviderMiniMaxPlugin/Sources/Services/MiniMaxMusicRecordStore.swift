import Foundation
import SwiftData
import LumiKernel
import SuperLogKit
import os

/// 纯数据副本，用于在 SwiftUI 视图中展示，与 SwiftData actor 隔离。
struct MiniMaxMusicRecordDTO: Identifiable, Sendable {
    let id: String
    let traceId: String?
    let prompt: String?
    let lyrics: String?
    let model: String
    let isInstrumental: Bool
    let lyricsOptimizer: Bool
    let audioUrl: String?
    let coverFeatureId: String?
    let audioFormat: String?
    let sampleRate: Int?
    let bitrate: Int?
    let aigcWatermark: Bool
    let status: String
    let audioURL: String?
    let durationMs: Int?
    let channels: Int?
    let fileSize: Int?
    let errorMessage: String?
    let createdAt: Date
    let completedAt: Date?
    let audioURLExpiresAt: Date?

    init(from model: MiniMaxMusicRecordModel) {
        self.id = model.id
        self.traceId = model.traceId
        self.prompt = model.prompt
        self.lyrics = model.lyrics
        self.model = model.model
        self.isInstrumental = model.isInstrumental
        self.lyricsOptimizer = model.lyricsOptimizer
        self.audioUrl = model.audioUrl
        self.coverFeatureId = model.coverFeatureId
        self.audioFormat = model.audioFormat
        self.sampleRate = model.sampleRate
        self.bitrate = model.bitrate
        self.aigcWatermark = model.aigcWatermark
        self.status = model.status
        self.audioURL = model.audioURL
        self.durationMs = model.durationMs
        self.channels = model.channels
        self.fileSize = model.fileSize
        self.errorMessage = model.errorMessage
        self.createdAt = model.createdAt
        self.completedAt = model.completedAt
        self.audioURLExpiresAt = model.audioURLExpiresAt
    }
}

/// 使用 SwiftData 持久化 MiniMax 音乐生成记录的后台存储服务。
///
/// 存储目录：`storage.pluginDataDirectory(for: "LLMProviderMiniMax")`。
actor MiniMaxMusicRecordStore: SuperLog {
    nonisolated static let emoji = "🎵"
    nonisolated static let verbose: Bool = false

    private static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.minimax.music-records"
    )

    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    /// 数据库根目录。
    nonisolated let directory: URL

    /// - Parameter databaseRootURL: 数据库根目录（`pluginDataDirectory(for:)` 的返回值）。
    init(databaseRootURL: URL) {
        try? FileManager.default.createDirectory(at: databaseRootURL, withIntermediateDirectories: true)
        self.directory = databaseRootURL

        let schema = Schema([MiniMaxMusicRecordModel.self])
        let storeURL = databaseRootURL.appendingPathComponent("minimax_music.sqlite", isDirectory: false)
        let configuration = ModelConfiguration(
            schema: schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
            if Self.verbose {
                Self.logger.info("\(Self.t)初始化完成,数据库位于 \(storeURL.path)")
            }
        } catch {
            Self.logger.error("\(Self.t)创建失败,回退到内存容器：\(error.localizedDescription)")
            container = (try? ModelContainer(for: MiniMaxMusicRecordModel.self)) ?? (try! ModelContainer())
        }
        self.modelContainer = container
        self.modelContext = ModelContext(modelContainer)
        self.modelContext.autosaveEnabled = true
    }

    // MARK: - Write

    /// 插入一条新的音乐生成记录（任务提交前调用）。
    func insertPendingRecord(
        prompt: String?,
        lyrics: String?,
        model: String,
        isInstrumental: Bool,
        lyricsOptimizer: Bool,
        audioUrl: String?,
        coverFeatureId: String?,
        audioFormat: String?,
        sampleRate: Int?,
        bitrate: Int?,
        aigcWatermark: Bool
    ) -> String {
        let recordID = UUID().uuidString
        let record = MiniMaxMusicRecordModel(
            id: recordID,
            prompt: prompt,
            lyrics: lyrics,
            model: model,
            isInstrumental: isInstrumental,
            lyricsOptimizer: lyricsOptimizer,
            audioUrl: audioUrl,
            coverFeatureId: coverFeatureId,
            audioFormat: audioFormat,
            sampleRate: sampleRate,
            bitrate: bitrate,
            aigcWatermark: aigcWatermark,
            status: MiniMaxMusicRecordStatus.pending.rawValue,
            createdAt: Date()
        )
        modelContext.insert(record)
        try? modelContext.save()
        return recordID
    }

    /// 标记生成成功。
    func markSuccess(
        recordID: String,
        traceId: String?,
        audioURL: URL,
        durationMs: Int?,
        channels: Int?,
        fileSize: Int?
    ) {
        let now = Date()
        let expiresAt = now.addingTimeInterval(24 * 3600) // 24 小时有效
        updateRecord(recordID: recordID) { model in
            model.traceId = traceId ?? model.traceId
            model.audioURL = audioURL.absoluteString
            model.durationMs = durationMs
            model.channels = channels
            model.fileSize = fileSize
            model.status = MiniMaxMusicRecordStatus.success.rawValue
            model.completedAt = now
            model.audioURLExpiresAt = expiresAt
        }
    }

    /// 标记生成失败。
    func markFailed(recordID: String, traceId: String?, errorMessage: String) {
        updateRecord(recordID: recordID) { model in
            model.traceId = traceId ?? model.traceId
            model.errorMessage = errorMessage
            model.status = MiniMaxMusicRecordStatus.failed.rawValue
            model.completedAt = Date()
        }
    }

    /// 标记用户取消。
    func markCancelled(recordID: String, traceId: String?) {
        updateRecord(recordID: recordID) { model in
            model.traceId = traceId ?? model.traceId
            model.status = MiniMaxMusicRecordStatus.cancelled.rawValue
            model.completedAt = Date()
        }
    }

    // MARK: - Read

    /// 分页查询记录（按创建时间倒序）。
    func fetchPage(limit: Int, beforeID: String? = nil) -> [MiniMaxMusicRecordDTO] {
        guard limit > 0 else { return [] }

        var descriptor = FetchDescriptor<MiniMaxMusicRecordModel>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        if let cursorID = beforeID,
           let cursorRecord = fetchModel(byID: cursorID) {
            let cursorDate = cursorRecord.createdAt
            descriptor.predicate = #Predicate<MiniMaxMusicRecordModel> { record in
                record.createdAt < cursorDate || (record.createdAt == cursorDate && record.id < cursorID)
            }
        }

        do {
            let results = try modelContext.fetch(descriptor)
            return results.map { MiniMaxMusicRecordDTO(from: $0) }
        } catch {
            Self.logger.error("\(Self.t)Failed to fetch MiniMax music records: \(error.localizedDescription)")
            return []
        }
    }

    /// 按 ID 查询单条记录。
    func fetchByID(recordID: String) -> MiniMaxMusicRecordDTO? {
        guard let model = fetchModel(byID: recordID) else { return nil }
        return MiniMaxMusicRecordDTO(from: model)
    }

    /// 查询指定状态的数量。
    func count(status: MiniMaxMusicRecordStatus? = nil) -> Int {
        let descriptor: FetchDescriptor<MiniMaxMusicRecordModel>
        if let status {
            let statusRaw = status.rawValue
            descriptor = FetchDescriptor<MiniMaxMusicRecordModel>(
                predicate: #Predicate { $0.status == statusRaw }
            )
        } else {
            descriptor = FetchDescriptor<MiniMaxMusicRecordModel>()
        }

        do {
            return try modelContext.fetchCount(descriptor)
        } catch {
            Self.logger.error("\(Self.t)Failed to count MiniMax music records: \(error.localizedDescription)")
            return 0
        }
    }

    /// 删除指定记录。
    func delete(recordID: String) {
        guard let model = fetchModel(byID: recordID) else { return }
        modelContext.delete(model)
        try? modelContext.save()
    }

    // MARK: - Private

    private func fetchModel(byID recordID: String) -> MiniMaxMusicRecordModel? {
        let predicate = #Predicate<MiniMaxMusicRecordModel> { $0.id == recordID }
        let descriptor = FetchDescriptor<MiniMaxMusicRecordModel>(predicate: predicate)
        return try? modelContext.fetch(descriptor).first
    }

    private func updateRecord(recordID: String, mutate: (MiniMaxMusicRecordModel) -> Void) {
        guard let model = fetchModel(byID: recordID) else {
            Self.logger.warning("\(Self.t)Record not found for update: \(recordID)")
            return
        }
        mutate(model)
        try? modelContext.save()
    }
}
