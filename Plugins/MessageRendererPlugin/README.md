# MessageRendererPlugin

核心消息渲染插件。

## 功能

负责注册所有内置消息渲染器，包括用户消息、助手消息、系统消息、状态消息和错误消息的渲染逻辑。

## 结构

```
Sources/
├── MessageRendererPlugin.swift       # 插件入口
├── MessageRendererRuntime.swift      # 渲染运行时
├── Message/                          # 消息模型
├── MessageComponent/                 # 可复用消息组件
├── Renderers/                        # 各类型消息渲染器
└── Components/                       # 气泡样式等 UI 组件
```
