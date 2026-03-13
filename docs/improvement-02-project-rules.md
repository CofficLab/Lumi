# 改进建议：项目规则配置系统

**参考产品**: Cursor (.cursorrules), Claude Code (CLAUDE.md)  
**优先级**: 🔴 高  
**影响范围**: PromptService, ContextService, AgentTool

---

## 背景

Cursor 的 `.cursorrules` 和 Claude Code 的 `CLAUDE.md` 允许用户为每个项目定义自定义规则，指导 AI 如何理解和处理代码。这是提高 AI 辅助质量的关键功能。

当前 Lumi 项目缺少这种项目级别的规则配置系统。

---

## 改进方案

### 1. 规则文件格式设计

支持 `.lumi/rules` 目录，包含多个规则文件：

```
project/
├── .lumi/
│   ├── rules           # 主规则文件
│   ├── context.md      # 项目上下文说明
│   ├── conventions.md  # 代码规范
│   └── tools/          # 自定义工具配置
│       └── custom-tools.yaml
```

#### 主规则文件示例 (.lumi/rules)

```yaml
# Lumi 项目规则配置
version: 1.0

# 项目基本信息
project:
  name: Lumi
  type: macos-app
  language: swift
  minimum_target: macOS 13.0

# AI 行为配置
ai:
  # 代码风格偏好
  style:
    indent: 4
    max_line_length: 120
    prefer_swift_ui: true
    use_async_await: true
  
  # 响应偏好
  response:
    language: zh-CN
    include_code_comments: true
    explain_changes: true
  
  # 安全限制
  security:
    allowed_paths:
      - /Users/*/Code/**
      - /Users/*/Documents/**
    denied_paths:
      - /etc/**
      - /System/**
      - ~/.ssh/**
      - ~/.gnupg/**
    
    # 命令执行限制
    allowed_commands:
      - git
      - swift
      - xcodebuild
      - npm
    denied_commands:
      - rm -rf /
      - sudo
      - chmod 777

# 上下文配置
context:
  # 总是包含的文件
  always_include:
    - README.md
    - Package.swift
    - .lumi/context.md
  
  # 忽略的文件模式
  ignore_patterns:
    - "*.generated.swift"
    - "DerivedData/**"
    - ".build/**"
    - "*.xcuserstate"
  
  # 重要文件（高优先级）
  important_files:
    - LumiApp/Core/Services/LLM/*.swift
    - LumiApp/Core/Models/*.swift
    - LumiApp/Core/Stores/*.swift

# 工具配置
tools:
  # 启用的工具
  enabled:
    - read_file
    - write_file
    - run_command
    - search_code
    - terminal
  
  # 禁用的工具
  disabled:
    - delete_file
    - format_disk
  
  # 工具特定配置
  config:
    terminal:
      default_shell: zsh
      timeout: 30000
    
    read_file:
      max_file_size: 10MB

# 知识库配置
knowledge:
  # 外部文档链接
  docs:
    - url: https://developer.apple.com/documentation/
      type: web
      refresh: weekly
    
    - path: ./docs/
      type: local
  
  # 自定义知识条目
  custom:
    - "This project uses MVVM architecture"
    - "All services should inherit from SuperLog"
    - "Plugins must implement PluginProtocol"
```

---

### 2. 规则加载服务

```swift
/// 项目规则服务
class ProjectRulesService {
    /// 规则缓存
    private var rulesCache: [String: ProjectRules] = [:]
    
    /// 加载项目规则
    func loadRules(for projectPath: String) async throws -> ProjectRules {
        let rulesPath = projectPath.appendingPathComponent(".lumi/rules")
        
        // 检查缓存
        if let cached = rulesCache[projectPath], !cached.isExpired {
            return cached
        }
        
        // 解析规则文件
        var rules = ProjectRules.default
        
        if FileManager.default.fileExists(atPath: rulesPath) {
            let data = try Data(contentsOf: URL(fileURLWithPath: rulesPath))
            rules = try YAMLDecoder().decode(ProjectRules.self, from: data)
        }
        
        // 加载额外的 markdown 文件
        rules.context = try loadContextFiles(from: projectPath)
        
        // 缓存规则
        rulesCache[projectPath] = rules
        
        return rules
    }
    
    /// 监听规则文件变更
    func watchRulesChanges(for projectPath: String) async {
        let watcher = FileWatcher(path: projectPath.appendingPathComponent(".lumi"))
        
        for await event in watcher.events {
            switch event {
            case .modified, .created:
                rulesCache.removeValue(forKey: projectPath)
                // 通知规则更新
                NotificationCenter.default.post(
                    name: .projectRulesDidChange,
                    object: nil,
                    userInfo: ["projectPath": projectPath]
                )
            default:
                break
            }
        }
    }
}

/// 项目规则模型
struct ProjectRules: Codable {
    let version: String
    let project: ProjectInfo
    let ai: AIConfig
    let context: ContextConfig
    let tools: ToolsConfig
    let knowledge: KnowledgeConfig?
    
    /// 默认规则
    static let `default` = ProjectRules(
        version: "1.0",
        project: ProjectInfo(),
        ai: AIConfig(),
        context: ContextConfig(),
        tools: ToolsConfig(),
        knowledge: nil
    )
    
    /// 是否过期（用于缓存）
    var isExpired: Bool {
        // 5分钟过期
        loadedAt.timeIntervalSinceNow < -300
    }
}
```

---

### 3. 规则注入到提示词

```swift
extension PromptService {
    /// 构建包含项目规则的系统提示词
    func buildSystemPrompt(
        with rules: ProjectRules,
        conversation: Conversation
    ) async -> String {
        var prompt = baseSystemPrompt
        
        // 添加项目上下文
        prompt += "\n\n## 项目信息\n"
        prompt += "- 项目名称: \(rules.project.name)\n"
        prompt += "- 项目类型: \(rules.project.type)\n"
        prompt += "- 主要语言: \(rules.project.language)\n"
        
        // 添加代码规范
        prompt += "\n\n## 代码规范\n"
        prompt += buildCodeConventions(from: rules)
        
        // 添加安全限制
        prompt += "\n\n## 安全限制\n"
        prompt += buildSecurityConstraints(from: rules)
        
        // 添加自定义上下文
        if let context = rules.context?.customContext {
            prompt += "\n\n## 项目特定说明\n"
            prompt += context
        }
        
        return prompt
    }
    
    private func buildCodeConventions(from rules: ProjectRules) -> String {
        var conventions = ""
        
        let style = rules.ai.style
        conventions += "- 缩进使用 \(style.indent) 个空格\n"
        conventions += "- 最大行宽 \(style.maxLineLength) 字符\n"
        
        if style.preferSwiftUI {
            conventions += "- 优先使用 SwiftUI\n"
        }
        
        if style.useAsyncAwait {
            conventions += "- 使用 async/await 而非回调\n"
        }
        
        return conventions
    }
    
    private func buildSecurityConstraints(from rules: ProjectRules) -> String {
        var constraints = "### 文件访问限制\n"
        
        let security = rules.ai.security
        
        constraints += "允许访问的路径:\n"
        for path in security.allowedPaths {
            constraints += "- \(path)\n"
        }
        
        constraints += "\n禁止访问的路径:\n"
        for path in security.deniedPaths {
            constraints += "- \(path)\n"
        }
        
        constraints += "\n### 命令执行限制\n"
        constraints += "允许的命令: \(security.allowedCommands.joined(separator: ", "))\n"
        constraints += "禁止的命令: \(security.deniedCommands.joined(separator: ", "))\n"
        
        return constraints
    }
}
```

---

### 4. 工具权限过滤器

```swift
/// 工具权限过滤器
class ToolPermissionFilter {
    let rules: ProjectRules
    
    init(rules: ProjectRules) {
        self.rules = rules
    }
    
    /// 检查工具是否允许执行
    func canExecute(
        tool: String,
        arguments: [String: ToolArgument]
    ) -> Result<Void, ToolPermissionError> {
        // 检查工具是否被禁用
        if rules.tools.disabled.contains(tool) {
            return .failure(.toolDisabled(tool))
        }
        
        // 根据工具类型进行特定检查
        switch tool {
        case "read_file", "write_file":
            return checkFileAccess(arguments)
        case "run_command", "terminal":
            return checkCommandPermission(arguments)
        default:
            return .success(())
        }
    }
    
    private func checkFileAccess(
        _ arguments: [String: ToolArgument]
    ) -> Result<Void, ToolPermissionError> {
        guard let path = arguments["path"]?.value as? String else {
            return .success(())
        }
        
        let expandedPath = (path as NSString).expandingTildeInPath
        
        // 检查是否在禁止路径中
        for deniedPath in rules.ai.security.deniedPaths {
            if expandedPath.hasPrefix(deniedPath) {
                return .failure(.pathDenied(path))
            }
        }
        
        // 检查是否在允许路径中
        for allowedPath in rules.ai.security.allowedPaths {
            if expandedPath.hasPrefix(allowedPath) {
                return .success(())
            }
        }
        
        return .failure(.pathDenied(path))
    }
    
    private func checkCommandPermission(
        _ arguments: [String: ToolArgument]
    ) -> Result<Void, ToolPermissionError> {
        guard let command = arguments["command"]?.value as? String else {
            return .success(())
        }
        
        // 解析命令
        let commandParts = command.split(separator: " ").map(String.init)
        guard let baseCommand = commandParts.first else {
            return .success(())
        }
        
        // 检查是否在禁止列表
        if rules.ai.security.deniedCommands.contains(baseCommand) {
            return .failure(.commandDenied(baseCommand))
        }
        
        return .success(())
    }
}

enum ToolPermissionError: Error {
    case toolDisabled(String)
    case pathDenied(String)
    case commandDenied(String)
}
```

---

### 5. 快速配置命令

提供简单的配置方式：

```swift
/// 规则配置命令
struct RulesCommand: Command {
    mutating func run() async throws {
        // /rules init - 初始化规则文件
        // /rules show - 显示当前规则
        // /rules validate - 验证规则文件
        // /rules set key=value - 设置规则
    }
}

// 使用示例：
// /rules init
// /rules set ai.style.indent=2
// /rules set ai.security.deniedPaths+=/etc/**
// /rules show
```

---

## 实施计划

### 阶段 1: 基础设施 (1-2 周)
1. 定义规则文件格式
2. 实现 `ProjectRulesService`
3. 实现规则文件解析

### 阶段 2: 集成 (1-2 周)
1. 修改 `PromptService` 注入规则
2. 实现 `ToolPermissionFilter`
3. 添加规则热重载

### 阶段 3: 增强 (1 周)
1. 添加 `/rules` 命令
2. 实现规则模板系统
3. 添加规则验证工具

---

## 预期效果

1. **项目特定定制**: 每个项目可以有自己的 AI 行为规则
2. **安全性提升**: 细粒度的文件和命令权限控制
3. **代码一致性**: AI 生成的代码符合项目规范
4. **上下文增强**: 项目特定的背景知识

---

## 参考资源

- [Cursor Rules 文档](https://cursor.sh/docs/rules)
- [Claude Code CLAUDE.md](https://docs.anthropic.com/claude-code)
- [YAML 规范](https://yaml.org/spec/)

---

*创建时间: 2026-03-13*