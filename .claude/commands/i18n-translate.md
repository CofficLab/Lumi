# 补充中文翻译

检查并补充 Localizable.xcstrings 文件中缺少的简体中文 (zh-Hans) 和繁体中文 (zh-HK) 翻译。

## 工作流程

0. **清理过期条目**
   - 找出所有带有 `"extractionState" : "stale"` 的条目
   - 删除这些条目（包括整个 key-value 对）
   - 报告删除的条目数量

1. **分析文件**
   - 读取 `/Users/angel/Code/Coffic/Lumi/Localizable.xcstrings` 文件
   - 统计总条目数和缺少翻译的条目数
   - 列出所有缺少 zh-Hans 或 zh-HK 翻译的条目

2. **翻译缺失内容**
   - 对于每个缺少翻译的条目，获取英文原文
   - 将英文翻译为简体中文 (zh-Hans)
   - 将简体中文转换为繁体中文 (zh-HK)
   - 保持占位符格式（如 %@、%lld、%1$@ 等）不变
   - 保持原有的 JSON 结构和格式

3. **更新文件**
   - 将翻译结果添加到对应的 localizations 中
   - 保持 state 为 "translated"
   - 保持缩进和格式一致

## 翻译原则

- 使用准确的技术术语翻译
- 保持 macOS/iOS 应用的用词习惯
- UI 文本要简洁明了
- 占位符必须原样保留
- 专有名词（如 API、SQLite、Host 等）可保持英文

## 重要规则

- **优先处理**：先删除所有 stale 条目，再进行翻译
- 删除 stale 条目时保持 JSON 格式正确（注意逗号）
- 使用中文与用户交流
- 每翻译一个条目后立即更新文件，不要批量处理
- 处理完成后报告删除的条目数量和翻译的总数量
