# DebugBadgePlugin

在工具栏右上角显示一个 **Debug** 标签/badge，当应用以 Debug 配置编译时自动显示。

## 功能

- 使用 `#if DEBUG` 检测应用是否运行在 Debug 配置下
- 在工具栏右上角显示 Debug 标签
- 标签使用主题警告色（橙色），便于识别
- Release 配置下完全不编译相关代码，无性能影响

## 使用方式

该插件默认启用（`.alwaysOn`），无需额外配置。

切换 Xcode 的 Build Configuration 为 Debug 或 Release 即可看到效果。
