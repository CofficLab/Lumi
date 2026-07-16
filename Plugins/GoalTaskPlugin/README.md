# GoalTaskPlugin

目标导向的任务管理插件，为 Lumi 提供 Goal（目标）+ Task（任务）两层结构的任务追踪能力。

## 核心概念

### Goal（目标）
- 代表 LLM 要达成的最终结果/意图
- 包含标题、描述、成功标准
- 支持多种状态：pending / in_progress / completed / blocked / failed / skipped

### Task（任务）
- 为实现 Goal 而执行的具体步骤
- 支持并行执行（通过 `parallelGroup` 标识）
- 包含给用户看的标题 + 给 LLM 看的详细描述和执行上下文

## 工具列表

| 工具 ID | 用途 |
|---------|------|
| `create_goal` | 创建目标及其关联任务 |
| `update_task_status` | 更新任务状态 |
| `update_goal_status` | 手动更新目标状态（如标记为 blocked） |
| `get_goal_progress` | 查询目标进度 |
| `add_tasks_to_goal` | 向已有目标追加任务 |

## 使用示例

```
用户: 帮我构建一个用户认证系统

LLM 调用 create_goal:
{
  "title": "构建用户认证系统",
  "description": "实现完整的注册、登录、token 刷新功能",
  "successCriteria": "用户可以通过邮箱密码登录并获得 JWT token",
  "tasks": [
    {
      "title": "创建 User 模型",
      "description": "定义 User 数据结构",
      "executionContext": "文件: Models/User.swift, 使用 SwiftData",
      "parallelGroup": "A"
    },
    {
      "title": "创建 AuthService",
      "description": "实现登录、注册方法",
      "parallelGroup": "A"
    },
    {
      "title": "编写登录 API",
      "description": "POST /login 端点",
      "parallelGroup": "B"
    }
  ]
}

LLM 执行并行组 A 的两个任务，完成后调用 update_task_status
LLM 执行并行组 B 的任务
所有任务完成后，Goal 自动标记为 completed
```

## 并行执行

通过 `parallelGroup` 字段标识可以并行执行的任务：
- 相同 group 的任务可以并发执行
- 不同 group 的任务按顺序执行（group A 完成后才能开始 group B）

## 阻塞处理

当 LLM 发现目标无法实现时：
1. 调用 `update_goal_status` 设置 status 为 `blocked`
2. 提供 `blocked_reason` 说明原因
3. 可选提供 `suggested_actions` 建议用户选择
4. 系统会通知用户并暂停任务执行
5. 用户回复后，LLM 继续处理