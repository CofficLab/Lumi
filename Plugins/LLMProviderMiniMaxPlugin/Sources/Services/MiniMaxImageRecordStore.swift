import Foundation
import SwiftData
import KernelLumi
import SuperLogKit
import os

/// 纯数据副本，用于在 SwiftUI 视图中展示，与 SwiftData actor 隔离。
struct MiniMaxImageRecordDTO: Identifiable, Sendable {
    let id: String
    let taskID: String?
    let prompt: String
    let model: String
    let subjectReference: String?
    let styleType: String?
    let styleWeight: Float?
    let aspectRatio: String?
    let width: Int?
    let height: Int?
    let n: Int
    let promptOptimizer: Bool
    let aigcWatermark: Bool
    let status: String
    let successCount: Int
    let failedCount: Int
    let imageURLs: String?
    let errorMessage: String?
    let createdAt: Date
    let completedAt: Date?
    let imageURLExpiresAt: Date?

    init(from model: MiniMaxImageRecordModel) {
        self.id = model.id
        self.taskID = model.taskID
        self.prompt = model.prompt
        self.model = model.model
        self.subjectReference = model.subjectReference
        self.styleType = model.styleType
        self.styleWeight = model.styleWeight
        self.aspectRatio = model.aspectRatio
        self.width = model.width
        self.height = model.height
        self.n = model.n
        self.promptOptimizer = model.promptOptimizer
        self.aigcWatermark = model.aigcWatermark
        self.status = model.status
        self.successCount = model.successCount
        self.failedCount = model.failedCount
        self.imageURLs = model.imageURLs
        self.errorMessage = model.errorMessage
        self.createdAt = model.createdAt
        self.completedAt = model.completedAt
        self.imageURLExpiresAt = model.imageURLExpiresAt
    }

    /// 解析 imageUrls JSON 字符串为 URL 数组。
    var parsedImageURLs: [URL] {
        guard let json = imageURLs,
              let data = json.data(using: .utf8),
              let strings = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return strings.compactMap { URL(string: $0) }
    }
}

/// 使用 SwiftData 持久化 MiniMax 图片生成记录的后台存储服务。
///
/// 存储目录：`storage.pluginDataDirectory(for: "LLMProviderMiniMax")`。
actor MiniMaxImageRecordStore: SuperLog {
    nonisolated static let emoji = "🖼️"
    nonisolated static let verbose: Bool = false

    private static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.minimax.image-records"
    )

    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    /// 数据库根目录。
    nonisolated let directory: URL

    /// - Parameter databaseRootURL: 数据库根目录（`pluginDataDirectory(for:)` 的返回值）。
    init(databaseRootURL: URL) {
        try? FileManager.default.createDirectory(at: databaseRootURL, withIntermediateDirectories: true)
        self.directory = databaseRootURL

        let schema = Schema([MiniMaxImageRecordModel.self])
        let storeURL = databaseRootURL.appendingPathComponent("minimax_images.sqlite", isDirectory: false)
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
            container = (try? ModelContainer(for: MiniMaxImageRecordModel.self)) ?? (try! ModelContainer())
        }
        self.modelContainer = container
        self.modelContext = ModelContext(modelContainer)
        self.modelContext.autosaveEnabled = true
    }

    // MARK: - Write

    /// 插入一条新的图片生成记录（任务提交前调用）。
    func insertPendingRecord(
        prompt: String,
        model: String,
        subjectReference: [MiniMaxImageSubjectReference]?,
        styleType: String?,
        styleWeight: Float?,
        aspectRatio: String?,
        width: Int?,
        height: Int?,
        n: Int,
        promptOptimizer: Bool,
        aigcWatermark: Bool
    ) -> String {
        let recordID = UUID().uuidString
        // 将 subjectReference 序列化为 JSON 字符串存储
        let subjectRefJSON: String? = {
            guard let refs = subjectReference, !refs.isEmpty else { return nil }
            let data = try? JSONEncoder().encode(refs)
            return data.flatMap { String(data: $0, encoding: .utf8) }
        }()
        let record = MiniMaxImageRecordModel(
            id: recordID,
            prompt: prompt,
            model: model,
            subjectReference: subjectRefJSON,
            styleType: styleType,
            styleWeight: styleWeight,
            aspectRatio: aspectRatio,
            width: width,
            height: height,
            n: n,
            promptOptimizer: promptOptimizer,
            aigcWatermark: aigcWatermark,
            status: MiniMaxImageRecordStatus.pending.rawValue,
            createdAt: Date()
        )
        modelContext.insert(record)
        try? modelContext.save()
        return recordID
    }

    /// 标记生成成功。
    func markSuccess(
        recordID: String,
        taskID: String?,
        imageURLs: [URL],
        successCount: Int,
        failedCount: Int
    ) {
        let now = Date()
        let expiresAt = now.addingTimeInterval(24 * 3600) // 24 小时有效
        let urlsJSON = try? String(
            data: JSONEncoder().encode(imageURLs.map { $0.absoluteString }),
            encoding: .utf8
        )
        updateRecord(recordID: recordID) { model in
            model.taskID = taskID ?? model.taskID
            model.imageURLs = urlsJSON
            model.successCount = successCount
            model.failedCount = failedCount
            model.status = MiniMaxImageRecordStatus.success.rawValue
            model.completedAt = now
            model.imageURLExpiresAt = expiresAt
        }
    }

    /// 标记生成失败。
    func markFailed(recordID: String, taskID: String?, errorMessage: String) {
        updateRecord(recordID: recordID) { model in
            model.taskID = taskID ?? model.taskID
            model.errorMessage = errorMessage
            model.status = MiniMaxImageRecordStatus.failed.rawValue
            model.completedAt = Date()
        }
    }

    /// 标记用户取消。
    func markCancelled(recordID: String, taskID: String?) {
        updateRecord(recordID: recordID) { model in
            model.taskID = taskID ?? model.taskID
            model.status = MiniMaxImageRecordStatus.cancelled.rawValue
            model.completedAt = Date()
        }
    }

    // MARK: - Read

    /// 分页查询记录（按创建时间倒序）。
    func fetchPage(limit: Int, beforeID: String? = nil) -> [MiniMaxImageRecordDTO] {
        guard limit > 0 else { return [] }

        var descriptor = FetchDescriptor<MiniMaxImageRecordModel>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        if let cursorID = beforeID,
           let cursorRecord = fetchModel(byID: cursorID) {
            let cursorDate = cursorRecord.createdAt
            descriptor.predicate = #Predicate<MiniMaxImageRecordModel> { record in
                record.createdAt < cursorDate || (record.createdAt == cursorDate && record.id < cursorID)
            }
        }

        do {
            let results = try modelContext.fetch(descriptor)
            return results.map { MiniMaxImageRecordDTO(from: $0) }
        } catch {
            Self.logger.error("\(Self.t)Failed to fetch MiniMax image records: \(error.localizedDescription)")
            return []
        }
    }

    /// 按 ID 查询单条记录。
    func fetchByID(recordID: String) -> MiniMaxImageRecordDTO? {
        guard let model = fetchModel(byID: recordID) else { return nil }
        return MiniMaxImageRecordDTO(from: model)
    }

    /// 查询指定状态的数量。
    func count(status: MiniMaxImageRecordStatus? = nil) -> Int {
        let descriptor: FetchDescriptor<MiniMaxImageRecordModel>
        if let status {
            let statusRaw = status.rawValue
            descriptor = FetchDescriptor<MiniMaxImageRecordModel>(
                predicate: #Predicate { $0.status == statusRaw }
            )
        } else {
            descriptor = FetchDescriptor<MiniMaxImageRecordModel>()
        }

        do {
            return try modelContext.fetchCount(descriptor)
        } catch {
            Self.logger.error("\(Self.t)Failed to count MiniMax image records: \(error.localizedDescription)")
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

    private func fetchModel(byID recordID: String) -> MiniMaxImageRecordModel? {
        let predicate = #Predicate<MiniMaxImageRecordModel> { $0.id == recordID }
        let descriptor = FetchDescriptor<MiniMaxImageRecordModel>(predicate: predicate)
        return try? modelContext.fetch(descriptor).first
    }

    private func updateRecord(recordID: String, mutate: (MiniMaxImageRecordModel) -> Void) {
        guard let model = fetchModel(byID: recordID) else {
            Self.logger.warning("\(Self.t)Record not found for update: \(recordID)")
            return
        }
        mutate(model)
        try? modelContext.save()
    }
}
