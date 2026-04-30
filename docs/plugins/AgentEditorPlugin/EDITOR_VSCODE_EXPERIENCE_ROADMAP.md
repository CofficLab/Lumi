# AgentEditorPlugin Roadmap

## 目标

在现有实现基础上，后续阶段只聚焦仍未完成、或与 VS Code 仍有明显差距的编辑器能力。

重点目标：

1. 补齐跨文件搜索、搜索结果持久化、导航深度这类高频工作流
2. 补齐 diagnostics / quick fix / peek / rename 之间的连续语言工作流
3. 补齐 snippet、复杂编辑语义和输入 fidelity
4. 把 contributor / context / when-clause 规则系统做完整
5. 建立更稳定的验证和回归门槛

## Phase 1: Search And Navigation Depth

- [ ] 参考 Xcode，在文件树上方增加右侧工作区 tabs，把 `Explorer / Open Editors / Outline` 这类常驻辅助视图收进同一容器
- [ ] 搜索结果树补齐文件级折叠、命中计数、结果状态保留
- [ ] `Search in Files` 增加 include / exclude / files to include / files to exclude 过滤模型
- [ ] `Search in Files` 增加 replace preview、批量替换确认与失败反馈
- [ ] `Search Editor` 从临时导出升级为稳定文档类型，支持 reopen / restore / rerun query
- [ ] sticky scroll 从当前 symbol bar 升级为真正的多层 scope sticky header
- [ ] go to symbol / workspace symbol 结果排序继续贴近 VS Code，补 query scoring 和最近命中权重

## Phase 2: Language Workflow Completion

- [ ] problems 导航补齐 next / previous problem、当前文件过滤、当前 group 语义
- [ ] quick fix 与 diagnostics 联动补齐 auto focus、selection memory、无动作时反馈策略
- [ ] peek 继续增强，支持结果内二次跳转、当前项高亮、更多上下文预览
- [ ] inline rename 增加更完整的失败回退、多文件影响确认、应用后结果反馈
- [ ] references / call hierarchy / workspace symbol 结果支持更统一的 keyboard-first 导航
- [ ] hover / signature / code action / diagnostics 在同一光标位置下的优先级与共存策略继续统一

## Phase 3: Snippet And Editing Fidelity

- [ ] snippet parser 补齐 choice placeholder、variable、transform、nested placeholder 支持
- [ ] linked placeholder editing 在复杂替换、撤销重做、额外 text edits 下继续增强稳定性
- [ ] snippet 会话与 undo/redo、completion accept、multi-cursor 同步补专项回归
- [ ] selection-aware indent / outdent、block edit、column-like editing 行为进一步对齐 VS Code
- [ ] folding 增加按 selection、按 symbol、递归展开/折叠等更细粒度命令
- [ ] 长文档下 bracket / indent / line edit 的边界行为补完整回归集

## Phase 4: Contribution Rules And Context System

- [ ] `EditorContextKey` 扩展到更完整的 editor / panel / selection / session / workbench 语义
- [ ] `EditorWhenClause` 增加更完整的表达能力与可读性约束
- [ ] 明确 menu location / panel location / status item placement 的稳定命名体系
- [ ] 让 command palette、context menu、panel、status item、settings 共用统一 context 解析入口
- [ ] 为 contributor rule engine 增加更完整的 contract tests
- [ ] 为样例插件补更复杂的 when-clause / dedupe / conflict 组合示例

## Phase 5: Validation And Release Gates

- [ ] 清理 editor 相关测试的现存阻塞，恢复更稳定的 `xcodebuild test` 路径
- [ ] 为 workbench / search / rename / quick fix / snippet 建立更明确的 smoke matrix
- [ ] 把 screenshot checklist 进一步收成可复用的验证模板
- [ ] 明确每次改动 editor kernel / surface / extension rule 时的最小验证集合
- [ ] 为剩余高风险交互建立回归优先级表
