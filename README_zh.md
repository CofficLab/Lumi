# Lumi

Lumi 是一款面向 macOS 的 AI 驱动的个人桌面助理应用。

📖 中文版 | [English](README.md)

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![macOS](https://img.shields.io/badge/macOS-13.0+-blue.svg)](https://developer.apple.com/macos/)
[![License](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

![Lumi 应用示意图](docs/hero.png)

## 🏗️ 架构设计

### 应用架构

```mermaid
graph TB
    subgraph "Lumi App"
        subgraph "Plugins 插件层"
            B1[Agent 工具插件<br/>文件树/终端/MCP]
            B2[系统管理插件<br/>CPU/内存/磁盘]
            B3[开发工具插件<br/>数据库/Docker/Brew]
            B4[效率工具插件<br/>剪贴板/文本]
        end
        
        subgraph "Core 核心层"
            A1[Bootstrap<br/>应用启动]
            A2[Services<br/>LLM/工具/任务]
            A3[Models & Entities<br/>数据模型]
            A4[Views & ViewModels<br/>视图与状态]
            A5[Middleware<br/>中间件系统]
            A6[Contact<br/>插件协议]
        end
        
        subgraph "UI 界面层"
            C1[Themes<br/>主题系统]
            C2[DesignSystem<br/>设计系统]
        end
    end
    
    B1 --> A6
    B2 --> A6
    B3 --> A6
    B4 --> A6
    B1 --> A2
    C2 --> C1
```

### 插件系统

- **SuperPlugin 协议**：所有插件的基础协议，定义生命周期和 UI 贡献点
- **扩展点**：导航栏、工具栏、状态栏、设置页、Agent 视图等
- **中间件**：支持拦截和修改消息发送、对话轮次等事件
- **Agent 工具**：插件可注册自定义工具供 AI 调用

### AI/Agent 工作流程

```mermaid
sequenceDiagram
    participant U as 用户
    participant M as 中间件
    participant L as LLM 服务
    participant T as 工具协调器
    participant E as 工具执行
    
    U->>M: 输入请求
    M->>M: 预处理
    M->>L: 发送请求
    L-->>M: 流式响应
    alt 需要工具调用
        L->>T: 工具调用请求
        T->>E: 执行工具
        E-->>T: 返回结果
        T->>L: 结果反馈
        L-->>M: 最终响应
    end
    M->>U: 显示结果
```

- **LLMProvider 协议**：统一的 LLM 接口，支持多供应商
- **ToolService**：工具注册、发现和执行
- **WorkerAgent**：后台任务执行代理

## 📋 系统要求

- macOS 13.0+
- Xcode 15.0+
- Swift 5.9+

## 🚀 构建与运行

### 1. 克隆仓库

```bash
git clone https://github.com/Coffic/Lumi.git
cd Lumi
```

### 2. 在 Xcode 中打开

```bash
open Lumi.xcodeproj
```

### 3. 构建与运行

- 选择合适的 macOS 目标
- 构建 (⌘B) 并运行 (⌘R)

## 📄 许可证

本项目采用 GNU 通用公共许可证 v3.0 - 查看 [LICENSE](LICENSE) 文件了解详情。
