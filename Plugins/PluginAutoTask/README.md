# PluginAutoTask

AutoTask 插件，为 Agent 提供任务拆解、状态追踪和自动推进能力。

## 核心功能

- **create_task**: 将复杂目标拆解为可执行的子任务列表
- **append_task**: 追加新任务到已有列表末尾
- **update_task**: 更新任务状态（进行中/已完成/跳过）
- **list_tasks**: 获取当前会话的任务列表
- **check_progress**: 查询当前会话的任务进度摘要
- **TaskContextMiddleware**: 每轮自动注入进度，保持 Agent 全局视野

## 依赖

- `AgentToolKit` - 工具协议和基础类型
- `SuperLogKit` - 日志协议

## 配置

App 侧需通过 `AutoTaskPlugin.configuration` 注入 `AutoTaskConfiguration` 协议实现，提供数据库目录路径。
