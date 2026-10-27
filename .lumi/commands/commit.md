# Git 提交向导

帮助用户生成符合 Conventional Commits 规范的提交信息。

## 工作流程

### 1. 暂存变更

```bash
git add -A  # 将所有变更（包括新增、修改、删除）加入暂存区
git status  # 确认所有变更已暂存，无遗漏的 untracked 文件
```

### 2. 查看变更

```bash
git diff --staged  # 查看暂存区的完整变更内容
```

### 3. 分析变更类型

根据变更内容确定提交类型：

- `feat`: 新功能
- `fix`: 修复 bug
- `docs`: 文档变更
- `style`: 代码格式（不影响功能）
- `refactor`: 重构
- `perf`: 性能优化
- `test`: 测试相关
- `chore`: 构建/工具配置

### 4. 生成提交信息

格式：
```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

### 5. 提交

```bash
git commit -m "<生成的提交信息>"
```

## 规则

- 标题行不超过 50 字符
- 正文每行不超过 72 字符
- 使用中文描述
- 使用祈使句（"添加" 而非 "添加了"）
- 不添加句号

## 示例

```
feat(plugin): 添加剪贴板管理插件

- 实现剪贴板历史记录
- 支持固定重要内容
- 添加搜索功能

Closes #123
```
