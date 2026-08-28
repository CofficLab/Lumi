# Support

支撑层：不归属 Model / Service / ViewModel / View 任一分类的辅助代码，
例如图表渲染、主题状态色与本地化辅助。

| 文件 | 职责 |
| --- | --- |
| `CPUMenuBarChartRenderer.swift` | CPU 菜单栏柱状图 NSImage 渲染 |
| `MemoryMenuBarChartRenderer.swift` | 内存菜单栏柱状图 NSImage 渲染 |
| `GPUMenuBarChartRenderer.swift` | GPU 菜单栏柱状图 NSImage 渲染 |
| `DeviceStatusColor.swift` | 指标状态分级与主题语义色映射 |
| `LumiPluginLocalization.swift` | 插件本地化查找辅助 |
