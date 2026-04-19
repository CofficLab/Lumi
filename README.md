# Lumi

Lumi is an AI-powered personal desktop assistant application for macOS.

📖 [中文版](README_zh.md) | English

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![macOS](https://img.shields.io/badge/macOS-13.0+-blue.svg)](https://developer.apple.com/macos/)
[![License](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

![Lumi Application](docs/hero.png)

## 🏗️ Architecture

### Application Architecture

```mermaid
graph BT
    subgraph "Lumi App"
        subgraph "Core Layer"
            A1[Bootstrap<br/>App Launch]
            A2[Services<br/>LLM/Tools/Tasks]
            A3[Models & Entities<br/>Data Models]
            A4[Views & ViewModels<br/>Views & State]
            A5[Middleware<br/>Middleware System]
            A6[Contact<br/>Plugin Protocol]
        end
        
        subgraph "Plugins Layer"
            B1[Agent Tools<br/>FileTree/Terminal/MCP]
            B2[System Management<br/>CPU/Memory/Disk]
            B3[Dev Tools<br/>Database/Docker/Brew]
            B4[Productivity<br/>Clipboard/Text]
        end
        
        subgraph "UI Layer"
            C1[Themes<br/>Theme System]
            C2[DesignSystem<br/>Design System]
        end
    end
    
    A6 --> B1
    A6 --> B2
    A6 --> B3
    A6 --> B4
    A2 --> B1
    C1 --> C2
```

### Plugin System

- **SuperPlugin Protocol**: Base protocol for all plugins, defining lifecycle and UI contribution points
- **Extension Points**: Navigation bar, toolbar, status bar, settings page, Agent views, etc.
- **Middleware**: Intercept and modify message sending, conversation turns, and other events
- **Agent Tools**: Plugins can register custom tools for AI invocation

### AI/Agent Workflow

```mermaid
sequenceDiagram
    participant U as User
    participant M as Middleware
    participant L as LLM Service
    participant T as Tool Coordinator
    participant E as Tool Executor
    
    U->>M: Input Request
    M->>M: Preprocessing
    M->>L: Send Request
    L-->>M: Streaming Response
    alt Tool Invocation Needed
        L->>T: Tool Call Request
        T->>E: Execute Tool
        E-->>T: Return Result
        T->>L: Result Feedback
        L-->>M: Final Response
    end
    M->>U: Display Result
```

- **LLMProvider Protocol**: Unified LLM interface supporting multiple providers
- **ToolService**: Tool registration, discovery, and execution
- **WorkerAgent**: Background task execution agent

## 📋 Requirements

- macOS 13.0+
- Xcode 15.0+
- Swift 5.9+

## 🚀 Build & Run

### 1. Clone the Repository

```bash
git clone https://github.com/Coffic/Lumi.git
cd Lumi
```

### 2. Open in Xcode

```bash
open Lumi.xcodeproj
```

### 3. Build and Run

- Select the macOS target
- Build (⌘B) and run (⌘R)


## 📄 License

This project is licensed under the GNU General Public License v3.0 - see [LICENSE](LICENSE) file for details.
