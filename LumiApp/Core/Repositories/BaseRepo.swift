import Foundation
import SwiftUI
import OSLog
import SwiftData

/// 数据访问层基础协议，定义通用的CRUD操作
protocol BaseRepoProtocol {
    /// 关联的模型类型
    associatedtype Model: PersistentModel

    /// 查询所有记录
    /// - Parameter sortedBy: 排序描述符
    /// - Returns: 查询到的模型数组
    func findAll(sortedBy: SortDescriptor<Model>) async throws -> [Model]

    /// 插入新记录
    /// - Parameter model: 要插入的模型实例
    func insert(_ model: Model) async throws

    /// 更新现有记录
    /// - Parameter model: 要更新的模型实例
    func update(_ model: Model) async throws

    /// 删除记录
    /// - Parameter model: 要删除的模型实例
    func delete(_ model: Model) async throws
}

/// 基础数据访问层实现类，提供通用的CRUD操作
class BaseRepo<Model: PersistentModel>: BaseRepoProtocol {
    /// SwiftData模型上下文
    let modelContext: ModelContext

    /// 初始化方法
    /// - Parameter modelContext: SwiftData模型上下文
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// 查询所有记录
    /// - Parameter sortedBy: 排序描述符
    /// - Returns: 查询到的模型数组
    func findAll(sortedBy: SortDescriptor<Model>) async throws -> [Model] {
        let descriptor = FetchDescriptor<Model>(sortBy: [sortedBy])
        return try modelContext.fetch(descriptor)
    }

    /// 插入新记录
    /// - Parameter model: 要插入的模型实例
    func insert(_ model: Model) async throws {
        modelContext.insert(model)
        try modelContext.save()
    }

    /// 更新现有记录
    /// - Parameter model: 要更新的模型实例
    func update(_ model: Model) async throws {
        try modelContext.save()
    }

    /// 删除记录
    /// - Parameter model: 要删除的模型实例
    func delete(_ model: Model) async throws {
        modelContext.delete(model)
        try modelContext.save()
    }
}

// MARK: - Preview

#Preview("App - Small Screen") {
    ContentLayout()
        .hideSidebar()
        .inRootView()
        .frame(width: 800, height: 600)
}

#Preview("App - Big Screen") {
    ContentLayout()
        .hideSidebar()
        .inRootView()
        .frame(width: 1200, height: 1200)
}
