# Xcode Build 规范

当任务涉及 Xcode 工程编译时，遵循以下步骤：

1. 先确认工程根目录：查找 `.xcodeproj` 或 `Package.swift`。
2. 区分目标：App / Framework / Package，使用对应 `xcodebuild` 参数。
3. 构建命令：
   - `xcodebuild -project Foo.xcodeproj -scheme Foo -configuration Debug build`
   - `xcodebuild -destination 'platform=iOS Simulator,name=iPhone 15' build`
4. 遇到构建错误先读取完整 error 上下文，不要只看最后一行。
5. 签名问题（code signing）通常需要检查 Signing & Capabilities 与
   DEVELOPMENT_TEAM 配置。
6. 模拟器问题优先检查 destination 名称是否与当前 Xcode 支持的模拟器匹配。