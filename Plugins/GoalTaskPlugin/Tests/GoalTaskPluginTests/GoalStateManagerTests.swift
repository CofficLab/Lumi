import Testing
import Foundation
@testable import GoalTaskPlugin

@Suite("Goal State Manager Tests")
struct GoalStateManagerTests {
    
    @Test("Create goal with tasks")
    func testCreateGoal() async throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("GoalTaskTest-\(UUID().uuidString)")
        let manager = GoalStateManager(databaseRootURL: tempDir)
        
        let result = try await manager.createGoal(
            conversationId: "test-conv-1",
            title: "Build auth system",
            description: "Test goal",
            successCriteria: "Users can login",
            tasks: [
                (title: "Task 1", description: "First task", executionContext: nil, parallelGroup: "A"),
                (title: "Task 2", description: "Second task", executionContext: nil, parallelGroup: "A"),
                (title: "Task 3", description: "Third task", executionContext: nil, parallelGroup: "B")
            ]
        )
        
        #expect(result.goal.title == "Build auth system")
        #expect(result.tasks.count == 3)
        #expect(result.goal.status == .inProgress)
        #expect(result.tasks[0].status == .inProgress)
        #expect(result.tasks[1].parallelGroup == "A")
    }
    
    @Test("Update task status auto-derives goal status")
    func testUpdateTaskStatusDerivesGoalStatus() async throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("GoalTaskTest-\(UUID().uuidString)")
        let manager = GoalStateManager(databaseRootURL: tempDir)
        
        let result = try await manager.createGoal(
            conversationId: "test-conv-2",
            title: "Simple goal",
            description: nil,
            successCriteria: nil,
            tasks: [
                (title: "Only task", description: nil, executionContext: nil, parallelGroup: nil)
            ]
        )
        
        let updateResult = try await manager.updateTaskStatus(
            id: result.tasks[0].id,
            status: .completed,
            result: "Done"
        )
        
        #expect(updateResult.task.status == .completed)
        #expect(updateResult.goal.status == .completed)
        #expect(updateResult.goal.completedAt != nil)
    }
    
    @Test("Update goal status to blocked")
    func testUpdateGoalStatusBlocked() async throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("GoalTaskTest-\(UUID().uuidString)")
        let manager = GoalStateManager(databaseRootURL: tempDir)
        
        let result = try await manager.createGoal(
            conversationId: "test-conv-3",
            title: "Blocked goal",
            description: nil,
            successCriteria: nil,
            tasks: [
                (title: "Task", description: nil, executionContext: nil, parallelGroup: nil)
            ]
        )
        
        let updated = try await manager.updateGoalStatus(
            id: result.goal.id,
            status: .blocked,
            blockedReason: "Missing API key"
        )
        
        #expect(updated.status == .blocked)
        #expect(updated.blockedReason == "Missing API key")
    }
    
    @Test("Fetch goals by conversation")
    func testFetchGoals() async throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("GoalTaskTest-\(UUID().uuidString)")
        let manager = GoalStateManager(databaseRootURL: tempDir)
        
        _ = try await manager.createGoal(
            conversationId: "test-conv-4",
            title: "Goal A",
            description: nil,
            successCriteria: nil,
            tasks: [(title: "Task", description: nil, executionContext: nil, parallelGroup: nil)]
        )
        
        _ = try await manager.createGoal(
            conversationId: "test-conv-4",
            title: "Goal B",
            description: nil,
            successCriteria: nil,
            tasks: [(title: "Task", description: nil, executionContext: nil, parallelGroup: nil)]
        )
        
        let goals = await manager.fetchGoals(conversationId: "test-conv-4")
        #expect(goals.count == 2)
    }
}