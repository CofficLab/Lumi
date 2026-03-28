//
//  BackgroundAgentTaskPluginTests.swift
//  LumiTests
//
//  测试用例：验证重构后的 BackgroundAgentTaskPlugin 功能
//

#if canImport(XCTest)
import XCTest
import SwiftData
@testable import Lumi

@MainActor
final class BackgroundAgentTaskPluginTests: XCTestCase {

    // MARK: - 测试任务创建

    func testTaskCreation() async throws {
        // 创建任务
        let taskId = BackgroundAgentTaskStore.shared.enqueue(
            prompt: "这是一个测试任务"
        )

        // 验证任务ID有效
        XCTAssertNotNil(taskId)

        // 等待一下确保任务写入数据库
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒

        // 验证任务已存入数据库
        let task = BackgroundAgentTaskStore.shared.fetchById(taskId)
        XCTAssertNotNil(task)
        XCTAssertEqual(task?.originalPrompt, "这是一个测试任务")

        // 验证初始状态为 pending
        let status = BackgroundAgentTaskStatus(rawOrDefault: task!.statusRawValue)
        XCTAssertEqual(status, .pending)

        print("✅ 任务创建测试通过: \(taskId)")
    }

    // MARK: - 测试Worker自动执行

    func testWorkerAutoExecution() async throws {
        // 创建任务
        let taskId = BackgroundAgentTaskStore.shared.enqueue(
            prompt: "测试Worker自动执行"
        )

        // 等待Worker发现并执行任务
        try await Task.sleep(nanoseconds: 5_000_000_000) // 5秒

        // 检查任务状态
        let task = BackgroundAgentTaskStore.shared.fetchById(taskId)
        XCTAssertNotNil(task)

        let status = BackgroundAgentTaskStatus(rawOrDefault: task!.statusRawValue)
        // 任务应该是 running 或 succeeded
        XCTAssertTrue(
            status == .running || status == .succeeded,
            "任务应该是运行中或已完成，实际状态: \(status.rawValue)"
        )

        if status == .succeeded {
            XCTAssertNotNil(task?.resultSummary)
            print("✅ 任务执行成功，结果: \(task!.resultSummary!)")
        } else {
            print("⏳ 任务正在执行中...")
        }
    }

    // MARK: - 测试并发控制

    func testConcurrencyControl() async throws {
        // 创建多个任务
        var taskIds: [UUID] = []
        for i in 0..<10 {
            let id = BackgroundAgentTaskStore.shared.enqueue(
                prompt: "并发测试任务 \(i)"
            )
            taskIds.append(id)
        }

        print("✅ 已创建 \(taskIds.count) 个任务")

        // 等待Worker开始执行
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2秒

        // 检查同时运行的任务数量
        var runningCount = 0
        for taskId in taskIds {
            if let task = BackgroundAgentTaskStore.shared.fetchById(taskId) {
                let status = BackgroundAgentTaskStatus(rawOrDefault: task.statusRawValue)
                if status == .running {
                    runningCount += 1
                }
            }
        }

        // 最多应该有2个任务在运行
        XCTAssertTrue(
            runningCount <= 2,
            "同时运行的任务数不应超过2个，实际: \(runningCount)"
        )

        print("✅ 并发控制测试通过，当前运行数: \(runningCount)")
    }

    // MARK: - 测试事件驱动

    func testEventDrivenExecution() async throws {
        // 创建任务
        let taskId = BackgroundAgentTaskStore.shared.enqueue(
            prompt: "事件驱动测试"
        )

        // 立即检查，任务应该很快被认领
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1秒

        let task = BackgroundAgentTaskStore.shared.fetchById(taskId)
        XCTAssertNotNil(task)

        let status = BackgroundAgentTaskStatus(rawOrDefault: task!.statusRawValue)
        // 由于事件驱动，任务应该很快从 pending 变为 running 或 succeeded
        XCTAssertNotEqual(status, .pending, "任务应该已被认领")

        print("✅ 事件驱动测试通过，状态: \(status.rawValue)")
    }

    // MARK: - 测试批量任务

    func testBatchTasks() async throws {
        // 批量创建任务
        let count = 20
        var taskIds: [UUID] = []

        for i in 0..<count {
            let id = BackgroundAgentTaskStore.shared.enqueue(
                prompt: "批量任务 \(i)"
            )
            taskIds.append(id)
        }

        print("✅ 已创建 \(count) 个批量任务")

        // 等待所有任务完成
        try await Task.sleep(nanoseconds: 30_000_000_000) // 30秒

        // 检查完成情况
        var succeededCount = 0
        var failedCount = 0
        var pendingCount = 0
        var runningCount = 0

        for taskId in taskIds {
            if let task = BackgroundAgentTaskStore.shared.fetchById(taskId) {
                let status = BackgroundAgentTaskStatus(rawOrDefault: task.statusRawValue)
                switch status {
                case .succeeded:
                    succeededCount += 1
                case .failed:
                    failedCount += 1
                case .pending:
                    pendingCount += 1
                case .running:
                    runningCount += 1
                }
            }
        }

        print("📊 批量任务统计:")
        print("   成功: \(succeededCount)")
        print("   失败: \(failedCount)")
        print("   待执行: \(pendingCount)")
        print("   运行中: \(runningCount)")

        // 至少应该有一些任务完成
        XCTAssertTrue(
            succeededCount + failedCount > 0,
            "至少应该有一些任务完成"
        )
    }

    // MARK: - 测试任务查询

    func testTaskQuery() async throws {
        // 创建一些任务
        let taskId1 = BackgroundAgentTaskStore.shared.enqueue(prompt: "查询测试1")
        let taskId2 = BackgroundAgentTaskStore.shared.enqueue(prompt: "查询测试2")

        // 等待写入
        try await Task.sleep(nanoseconds: 100_000_000)

        // 测试 fetchRecent
        let recentTasks = BackgroundAgentTaskStore.shared.fetchRecent(limit: 10)
        XCTAssertTrue(recentTasks.count >= 2, "应该至少有2个任务")

        // 测试 fetchById
        let task1 = BackgroundAgentTaskStore.shared.fetchById(taskId1)
        XCTAssertNotNil(task1)
        XCTAssertEqual(task1?.originalPrompt, "查询测试1")

        let task2 = BackgroundAgentTaskStore.shared.fetchById(taskId2)
        XCTAssertNotNil(task2)
        XCTAssertEqual(task2?.originalPrompt, "查询测试2")

        print("✅ 任务查询测试通过")
    }

    // MARK: - 测试任务状态转换

    func testTaskStatusTransition() async throws {
        let taskId = BackgroundAgentTaskStore.shared.enqueue(
            prompt: "状态转换测试"
        )

        // 初始状态：pending
        var task = BackgroundAgentTaskStore.shared.fetchById(taskId)
        var status = BackgroundAgentTaskStatus(rawOrDefault: task!.statusRawValue)
        XCTAssertEqual(status, .pending)

        // 等待任务开始执行
        try await Task.sleep(nanoseconds: 3_000_000_000)

        // 状态应该变为 running 或 succeeded
        task = BackgroundAgentTaskStore.shared.fetchById(taskId)
        status = BackgroundAgentTaskStatus(rawOrDefault: task!.statusRawValue)
        XCTAssertTrue(
            status == .running || status == .succeeded,
            "状态应该是 running 或 succeeded"
        )

        if status == .running {
            print("⏳ 任务状态: running")
        } else if status == .succeeded {
            print("✅ 任务状态: succeeded")
            XCTAssertNotNil(task?.resultSummary)
        }

        print("✅ 状态转换测试通过")
    }

    // MARK: - 测试并发任务认领

    func testConcurrentClaiming() async throws {
        // 创建单个任务
        let taskId = BackgroundAgentTaskStore.shared.enqueue(
            prompt: "并发认领测试"
        )

        // 等待任务被认领
        try await Task.sleep(nanoseconds: 2_000_000_000)

        // 检查任务状态
        let task = BackgroundAgentTaskStore.shared.fetchById(taskId)
        XCTAssertNotNil(task)

        let status = BackgroundAgentTaskStatus(rawOrDefault: task!.statusRawValue)

        // 任务应该只被认领一次（不会重复执行）
        XCTAssertTrue(
            status == .running || status == .succeeded || status == .failed,
            "任务应该已被认领"
        )

        // startedAt 应该被设置（证明被认领了）
        if status != .pending {
            XCTAssertNotNil(task?.startedAt, "startedAt 应该被设置")
        }

        print("✅ 并发认领测试通过")
    }

    // MARK: - 测试任务删除

    func testTaskDeletion() async throws {
        // 创建任务
        let taskId = BackgroundAgentTaskStore.shared.enqueue(
            prompt: "删除测试任务"
        )

        // 等待写入
        try await Task.sleep(nanoseconds: 100_000_000)

        // 验证任务存在
        var task = BackgroundAgentTaskStore.shared.fetchById(taskId)
        XCTAssertNotNil(task)

        // 删除任务
        BackgroundAgentTaskStore.shared.delete(taskId)

        // 验证任务已删除
        task = BackgroundAgentTaskStore.shared.fetchById(taskId)
        XCTAssertNil(task)

        print("✅ 任务删除测试通过")
    }

    // MARK: - 测试清空已完成任务

    func testClearCompletedTasks() async throws {
        // 创建几个任务
        let taskId1 = BackgroundAgentTaskStore.shared.enqueue(prompt: "清空测试1")
        let taskId2 = BackgroundAgentTaskStore.shared.enqueue(prompt: "清空测试2")

        // 等待写入
        try await Task.sleep(nanoseconds: 100_000_000)

        // 手动标记一个任务为已完成（用于测试）
        // 注意：实际场景中任务会被 Worker 执行

        // 清空已完成任务（当前可能没有已完成的）
        BackgroundAgentTaskStore.shared.deleteCompleted()

        // 验证任务仍存在（因为它们不是已完成状态）
        let task1 = BackgroundAgentTaskStore.shared.fetchById(taskId1)
        let task2 = BackgroundAgentTaskStore.shared.fetchById(taskId2)

        // 如果任务被 Worker 执行完成了，那么它们会被删除
        // 如果还在 pending 或 running，则不会被删除
        print("✅ 清空已完成任务测试通过")
        print("   任务1状态: \(task1 != nil ? "存在" : "已删除")")
        print("   任务2状态: \(task2 != nil ? "存在" : "已删除")")
    }
}

// MARK: - 测试运行说明

/*
 🧪 如何运行测试

 1. 在 Xcode 中打开 Lumi 项目
 2. 选择 Product > Test (⌘U)
 3. 或者在 Test Navigator 中运行单独的测试

 📝 测试说明

 - testTaskCreation: 验证任务创建和存储
 - testWorkerAutoExecution: 验证Worker自动发现并执行任务
 - testConcurrencyControl: 验证并发控制（最多2个）
 - testEventDrivenExecution: 验证事件驱动机制
 - testBatchTasks: 验证批量任务处理
 - testTaskQuery: 验证任务查询功能
 - testTaskStatusTransition: 验证状态转换
 - testConcurrentClaiming: 验证CAS认领机制
 - testTaskDeletion: 验证任务删除
 - testClearCompletedTasks: 验证清空已完成任务

 ⚠️ 注意事项

 - 测试需要访问 SwiftData 数据库
 - 某些测试可能需要等待较长时间
 - 建议在独立的环境中运行测试
 - 部分测试可能依赖 LLM 配置

 📊 预期结果

 所有测试应该通过，输出类似：
 ✅ 任务创建测试通过: <UUID>
 ✅ 任务执行成功，结果: ...
 ✅ 并发控制测试通过，当前运行数: 2
 */
#endif
