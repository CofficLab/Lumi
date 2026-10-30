# PluginToolLLMProvider

「用对话添加 LLM 供应商」插件：让用户直接对 LLM 说「帮我添加一个新的 LLM 供应商」，
由 LLM 调用本插件的工具产出**提案**，再由消息里的卡片完成确认与落库。

## 组成

| 组成 | 类型 | 职责 |
|------|------|------|
| `add_llm_provider` | `SuperAgentTool` | 解析并校验 LLM 给出的供应商信息，产出提案载荷（**无副作用**） |
| `LLMProviderRowRenderer` | `ToolCallRowRenderer` | 把工具结果渲染成「添加供应商」卡片 |
| `LLMProviderProposalCard` | `SwiftUI` | 可编辑的提案表单 + API Key 输入 + 确认落库 |
| `ProviderEndpointPolicy` | 纯逻辑 | 供应商端点地址的安全策略 |

## 数据流

```
用户：「帮我添加一个新的 LLM 供应商 Acme」
  ↓
LLM 调用 add_llm_provider(displayName:baseURL:apiFormat:models:)
  ↓
工具：校验端点与配置 → 返回正文 + 末尾 JSON 代码块（提案）
  ↓
渲染器：解码载荷 → 渲染卡片（不落盘）
  ↓
用户：在卡片里补 API Key → 点「添加」
  ↓
卡片：store.upsert(config) → 落盘 + 注册 → setApiKey(写入 Keychain)
```

## 设计约束

### 工具不产生副作用

工具**不写盘、不注册、不碰 Keychain**。它只产出提案。

原因有三：

1. LLM 给出的 `baseURL` 与模型名经常有偏差，直接落库会留下一个用不了的供应商；
2. 供应商配置决定了后续请求发往哪里，属于安全敏感项，应由用户确认；
3. 提案制让用户在卡片里修正 LLM 的猜测，成本远低于事后到设置页返工。

### API Key 不经过 LLM

工具的入参里**没有** API Key 字段。密钥只由卡片直接写入 Keychain
（`SuperLLMProvider.setApiKey`），既不进入配置文件，也不进入对话记录，
更不会被回传给模型端点。

### 端点安全策略

`baseURL` 由 LLM 决定时，它就是一个任意外连通道。`ProviderEndpointPolicy` 的规则：

| 目标 | 判定 | 允许的协议 |
|------|------|-----------|
| 回环地址（`localhost` / `127.0.0.0/8` / `::1`） | 本机 | `http` 或 `https` |
| 其它地址 | 远端 | 仅 `https` |

私网网段（`10/8`、`172.16/12`、`192.168/16`）、链路本地（`169.254/16`）、
CGNAT（`100.64/10`）与 `.local` 域名一律拒绝。

### 标识前缀

提案的供应商标识统一带 `custom-` 前缀，避免与内置供应商 id（如 `openai`）撞车——
同 id 注册会直接覆盖内置实现。卡片保存时还会再查一次：目标 id 已被非自定义
供应商占用时拒绝写入。

## 已知限制

- 自定义渲染器只在 V2 / V3 消息列表启用。V1（brief）模式走默认工具行，
  卡片不会出现（见 `ToolCallRowsView.allowsCustomToolRenderers`）。
- 本插件 `order = 120`，必须晚于供应商设置插件（`order = 100`）：自定义供应商
  的 Store 正是在那里注册进内核的。

## 测试

```bash
cd Packages/PluginToolLLMProvider && swift test
```
