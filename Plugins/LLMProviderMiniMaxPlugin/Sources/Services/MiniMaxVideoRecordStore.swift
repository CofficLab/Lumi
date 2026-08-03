import Foundation
import SwiftData
import LumiKernel
import SuperLogKit
import os

/// 纯数据副本，用于在 SwiftUI 视图中展示，与 SwiftData actor 隔离。
struct MiniMaxVideoRecordDTO: Identifiable, Sendable {
    let id: String
    let taskID: String?
    let fileID: String?
    let prompt: String
    let model: String
    let duration: Int
    let resolution: String
    let promptOptimizer: Bool
    let fastPretreatment: Bool
    let aigcWatermark: Bool
    let status: String
    let downloadURL: String?
    let fileName: String?
    let byteCount: Int64?
    let errorMessage: String?
    let createdAt: Date
    let completedAt: Date?
    let downloadURLExpiresAt: Date?

    init(from model: MiniMaxVideoRecordModel) {
        self.id = model.id
        self.taskID = model.taskID
        self.fileID = model.fileID
        self.prompt = model.prompt
        self.model = model.model
        self.duration = model.duration
        self.resolution = model.resolution
        self.promptOptimizer = model.promptOptimizer
        self.fastPretreatment = model.fastPretreatment
        self.aigcWatermark = model.aigcWatermark
        self.status = model.status
        self.downloadURL = model.downloadURL
        self.fileName = model.fileName
        self.byteCount = model.byteCount
        self.errorMessage = model.errorMessage
        self.createdAt = model.createdAt
        self.completedAt = model.completedAt
        self.downloadURLExpiresAt = model.downloadURLExpiresAt
    }
}

/// 使用 SwiftData 持久化 MiniMax 视频生成记录的后台存储服务。
///
/// 存储目录：`storage.pluginDataDirectory(for: "LLMProviderMiniMax")`。
actor MiniMaxVideoRecordStore: SuperLog {
    nonisolated static let emoji = "🎬"
    nonisolated static let verbose: Bool = false

    private static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.minimax.video-records"
    )

    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    /// 数据库根目录。
    nonisolated let directory: URL

    /// - Parameter databaseRootURL: 数据库根目录（`pluginDataDirectory(for:)` 的返回值）。
    init(databaseRootURL: URL) {
        try? FileManager.default.createDirectory(at: databaseRootURL, withIntermediateDirectories: true)
        self.directory = databaseRootURL

        let schema = Schema([MiniMaxVideoRecordModel.self])
        let storeURL = databaseRootURL.appendingPathComponent("minimax_videos.sqlite", isDirectory: false)
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
            container = (try? ModelContainer(for: MiniMaxVideoRecordModel.self)) ?? (try! ModelContainer())
        }
        self.modelContainer = container
        self.modelContext = ModelContext(modelContainer)
        self.modelContext.autosaveEnabled = true
    }

    // MARK: - Write

    /// 插入一条新的视频生成记录（任务提交时调用）。
    func insertPendingRecord(
        prompt: String,
        model: String,
        duration: Int,
        resolution: String,
        promptOptimizer: Bool,
        fastPretreatment: Bool,
        aigcWatermark: Bool
    ) -> String {
        let recordID = UUID().uuidString
        let record = MiniMaxVideoRecordModel(
            id: recordID,
            prompt: prompt,
            model: model,
            duration: duration,
            resolution: resolution,
            promptOptimizer: promptOptimizer,
            fastPretreatment: fastPretreatment,
            aigcWatermark: aigcWatermark,
            status: MiniMaxVideoRecordStatus.pending.rawValue,
            createdAt: Date()
        )
        modelContext.insert(record)
        try? modelContext.save()
        return recordID
    }

    /// 更新任务 ID（Step 1 成功后调用）。
    func updateTaskID(recordID: String, taskID: String) {
        updateRecord(recordID: recordID) { model in
            model.taskID = taskID
            model.status = MiniMaxVideoRecordStatus.generating.rawValue
        }
    }

    /// 标记生成成功（Step 3 完成后调用）。
    func markSuccess(
        recordID: String,
        taskID: String?,
        fileID: String?,
        downloadURL: String,
        fileName: String?,
        byteCount: Int64?
    ) {
        let now = Date()
        let expiresAt = now.addingTimeInterval(24 * 3600) // 24 小时有效
        updateRecord(recordID: recordID) { model in
            model.taskID = taskID ?? model.taskID
            model.fileID = fileID
            model.downloadURL = downloadURL
            model.fileName = fileName
            model.byteCount = byteCount
            model.status = MiniMaxVideoRecordStatus.success.rawValue
            model.completedAt = now
            model.downloadURLExpiresAt = expiresAt
        }
    }

    /// 标记生成失败。
    func markFailed(recordID: String, taskID: String?, errorMessage: String) {
        updateRecord(recordID: recordID) { model in
            model.taskID = taskID ?? model.taskID
            model.errorMessage = errorMessage
            model.status = MiniMaxVideoRecordStatus.failed.rawValue
            model.completedAt = Date()
        }
    }

    /// 标记用户取消。
    func markCancelled(recordID: String, taskID: String?) {
        updateRecord(recordID: recordID) { model in
            model.taskID = taskID ?? model.taskID
            model.status = MiniMaxVideoRecordStatus.cancelled.rawValue
            model.completedAt = Date()
        }
    }

    // MARK: - Read

    /// 分页查询记录（按创建时间倒序）。
    func fetchPage(limit: Int, beforeID: String? = nil) -> [MiniMaxVideoRecordDTO] {
        guard limit > 0 else { return [] }

        var descriptor = FetchDescriptor<MiniMaxVideoRecordModel>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        if let cursorID = beforeID,
           let cursorRecord = fetchModel(byID: cursorID) {
            let cursorDate = cursorRecord.createdAt
            descriptor.predicate = #Predicate<MiniMaxVideoRecordModel> { record in
                record.createdAt < cursorDate || (record.createdAt == cursorDate && record.id < cursorID)
            }
        }

        do {
            let results = try modelContext.fetch(descriptor)
            return results.map { MiniMaxVideoRecordDTO(from: $0) }
        } catch {
            Self.logger.error("\(Self.t)Failed to fetch MiniMax video records: \(error.localizedDescription)")
            return []
        }
    }

    /// 按 ID 查询单条记录。
    func fetchByID(recordID: String) -> MiniMaxVideoRecordDTO? {
        guard let model = fetchModel(byID: recordID) else { return nil }
        return MiniMaxVideoRecordDTO(from: model)
    }

    /// 查询指定状态的数量。
    func count(status: MiniMaxVideoRecordStatus? = nil) -> Int {
        let descriptor: FetchDescriptor<MiniMaxVideoRecordModel>
        if let status {
            let statusRaw = status.rawValue
            descriptor = FetchDescriptor<MiniMaxVideoRecordModel>(
                predicate: #Predicate { $0.status == statusRaw }
            )
        } else {
            descriptor = FetchDescriptor<MiniMaxVideoRecordModel>()
        }

        do {
            return try modelContext.fetchCount(descriptor)
        } catch {
            Self.logger.error("\(Self.t)Failed to count MiniMax video records: \(error.localizedDescription)")
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

    private func fetchModel(byID recordID: String) -> MiniMaxVideoRecordModel? {
        let predicate = #Predicate<MiniMaxVideoRecordModel> { $0.id == recordID }
        let descriptor = FetchDescriptor<MiniMaxVideoRecordModel>(predicate: predicate)
        return try? modelContext.fetch(descriptor).first
    }

    private func updateRecord(recordID: String, mutate: (MiniMaxVideoRecordModel) -> Void) {
        guard let model = fetchModel(byID: recordID) else {
            Self.logger.warning("\(Self.t)Record not found for update: \(recordID)")
            return
        }
        mutate(model)
        try? modelContext.save()
    }
}
