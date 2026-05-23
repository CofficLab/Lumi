# BrowserAgentPlugin

基于 [agent-browser](https://github.com/nicepkg/agent-browser) CLI 的浏览器自动化插件。

## 功能特性

- 🌐 **网页导航**：打开 URL、前进/后退、刷新
- 🖱️ **元素交互**：点击、输入、滚动、拖拽
- 📸 **截图**：页面截图、带标注截图
- 📋 **快照**：获取页面可访问性树（Accessibility Tree）
- 📝 **表单**：填写表单、下拉选择、文件上传
- ⚡ **JavaScript**：执行自定义脚本
- 🍪 **存储管理**：Cookie、LocalStorage 管理

## 前置要求

需要安装 `agent-browser` CLI 工具：

```bash
# npm（推荐）
npm install -g agent-browser

# Homebrew
brew install agent-browser

# Cargo
cargo install agent-browser

# 安装后下载 Chrome
agent-browser install
```

## 插件行为

### 自动检测

插件启动时会自动检测 `agent-browser` 是否已安装：
- ✅ **已安装**：工具可用
- ❌ **未安装**：工具不可用，会显示安装指南

### 工具列表

| 工具名 | 说明 |
|--------|------|
| `browser_agent` | 执行 agent-browser 命令 |

## 使用示例

### 基本用法

```
# 打开网页
browser_agent: open https://github.com

# 获取页面快照（AI 可读格式）
browser_agent: snapshot

# 点击元素
browser_agent: click @e2

# 填写表单
browser_agent: fill @e3 "hello@example.com"

# 截图
browser_agent: screenshot
```

### 高级用法

```
# 执行 JavaScript
browser_agent: eval "document.title"

# 获取页面文本
browser_agent: get text @e1

# 等待元素出现
browser_agent: wait 2000

# 管理 Cookie
browser_agent: cookies get
```

## 典型工作流

1. **打开目标网页**
   ```
   browser_agent: open https://example.com
   ```

2. **获取页面结构**
   ```
   browser_agent: snapshot
   ```

3. **分析并交互**
   ```
   browser_agent: click @e5
   browser_agent: fill @e10 "search query"
   browser_agent: press Enter
   ```

4. **获取结果**
   ```
   browser_agent: get text @result
   browser_agent: screenshot
   ```

## 错误处理

### agent-browser 未安装

如果用户未安装 agent-browser，工具会返回安装指南：

```
Error: agent-browser is not installed on this system.

To install agent-browser, run one of the following commands:

**Using npm (recommended):**
npm install -g agent-browser

**Using Homebrew:**
brew install agent-browser

**Using Cargo:**
cargo install agent-browser

After installation, run the following to download Chrome:
agent-browser install
```

### 命令超时

默认超时为 30 秒，可通过 `timeout` 参数调整：

```
browser_agent: open https://slow-site.com --timeout 60
```

### 命令取消

用户可以随时取消正在执行的命令。

## 配置

插件无需额外配置。agent-browser 的配置请参考其官方文档。

## 相关链接

- [agent-browser 官方文档](https://agent-browser.dev)
- [agent-browser GitHub](https://github.com/vercel-labs/agent-browser) (34k ⭐)
