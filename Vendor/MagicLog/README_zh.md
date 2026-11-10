# MagicLog

[![English](https://img.shields.io/badge/English-README-green)](README.md)

一个具有表情符号支持和线程信息的Swift日志协议，适用于iOS和macOS应用。

## 功能特性

- **统一的日志格式**: 具有表情符号标识符和线程信息的一致日志输出
- **线程感知**: 自动检测和显示当前线程QoS级别
- **表情符号生成**: 基于上下文字符串的自动表情符号生成
- **协议化设计**: 易于在任何Swift类或结构体中采用
- **SwiftUI就绪**: 与SwiftUI应用无缝集成

## 安装

### Swift Package Manager

将MagicLog作为依赖项添加到您的`Package.swift`中：

```swift
dependencies: [
    .package(url: "https://github.com/nookery/MagicLog.git", from: "1.0.0")
]
```

或者直接在Xcode中添加：

1. 转到文件 → 添加包...
2. 输入仓库URL：`https://github.com/nookery/MagicLog.git`
3. 选择您要使用的版本

## 使用方法

### 基本日志记录

```swift
import Foundation
import MagicLog

class UserManager: SuperLog {
    static var emoji: String { "👤" }  // 可选：自定义表情符号

    func login() {
        os_log("\(Self.t)开始登录处理") // 使用os_log输出带有线程信息和表情符号的日志

        if isMain {
            os_log("\(Self.t)在主线程执行")
        }

        // 带有原因的日志记录
        error("登录失败\(r("密码错误"))")
    }
}

// 输出示例：
// [UI] | 👤 UserManager           | 开始登录处理
// [UI] | 👤 UserManager           | 在主线程执行
// [UI] | 👤 UserManager           | 登录失败 ➡️ 密码错误
```

### 线程信息

MagicLog自动检测并显示线程QoS信息：

- `[UI]` - 用户交互（主线程）
- `[2️⃣]` - 用户发起
- `[3️⃣]` - 默认
- `[4️⃣]` - 实用工具
- `[5️⃣]` - 后台

### 表情符号生成

库包含基于字符串内容的自动表情符号生成：

```swift
import MagicLog

let message = "网络请求失败"
os_log("\(message.withContextEmoji)") // 输出: 🌐 网络请求失败

let success = "数据保存成功"
os_log("\(success.withContextEmoji)") // 输出: 💾 数据保存成功
```

## 协议方法

### 静态属性

- `emoji` - 类的自定义表情符号（如果不提供则自动生成）
- `t` - 带有表情符号和类名的线程信息前缀
- `author` - 不含泛型参数的类名
- `onAppear` - 标准化的"OnAppear"日志消息
- `onInit` - 标准化的"Init"日志消息

### 实例属性

- `author` - 与静态author属性相同
- `className` - author的别名
- `isMain` - 布尔值，表示当前线程是否为主线程
- `t` - 与静态t属性相同
- `a` - onAppear的别名
- `i` - onInit的别名

### 实例方法

- `r(_:)` - 使用箭头分隔符创建原因字符串
- `makeReason(_:)` - 创建格式化的原因字符串

## 要求

- iOS 17.0+
- macOS 14.0+
- Swift 5.9+

## 许可证

本项目采用MIT许可证 - 详见LICENSE文件。
