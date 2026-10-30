import Testing

/// 共享 `GoalTaskPluginSupport._sharedManager` 的测试的统一父 suite。
///
/// ## 为什么需要这个父 suite
///
/// `GoalTaskPluginSupport._sharedManager` 是**进程级静态可变状态**（工具层与
/// 两个生命周期钩子都通过 `Plugin.currentManager()` 读取它）。Swift Testing
/// 默认并行执行不同顶层 suite：若「工具层测试」与「钩子测试」分属不同顶层
/// suite，二者会同时给这个静态变量赋不同实例，于是
/// `fetchGoals(conversationId:)` 读到的是另一个数据库，返回空列表，
/// 表现为断言随机失败（注入段数为 0 而非预期值）。
///
/// `.serialized` 只保证**同一 suite 树内**的测试串行，因此把所有会写
/// `_sharedManager` 的 suite 都挂到这个标记了 `.serialized` 的父 suite 下，
/// 由父 suite 统一排队，跨文件、跨 suite 的竞态一并消除。
///
/// 约定：**任何需要 `GoalTaskPluginSupport._sharedManager` 的测试，
/// 都必须作为本类型的嵌套类型声明**（本文件内，或其他文件里用
/// `extension SharedManagerSuite { @Suite struct Xxx {} }`）。
///
/// `GoalStateManagerTests` / `GoalTaskPluginTests` 中的用例只操作自己传入的
/// manager 实例、不触碰静态状态，故仍作为独立顶层 suite 并行运行。
@Suite("Goal Shared Manager", .serialized)
struct SharedManagerSuite {}
