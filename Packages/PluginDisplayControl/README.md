# DisplayControlPlugin

External display DDC (Display Data Channel) control for Lumi.

- Brightness, Volume, Contrast control for external monitors via DDC/CI (VCP commands over I2C)
- Built-in display brightness via DisplayServices
- Apple Silicon DDC service matching (Arm64DDCMatcher)
- Debounced writes (150ms) to prevent DDC overload
- Unsupported controls are automatically disabled

Based on reference implementation from [hagimi-monitor](https://github.com/Acerola-1/hagimi-monitor).

> **重要规则：本插件包不能依赖其他插件包，也不能被其他插件包依赖。**
>
> 插件之间只通过 Provider 契约通信：共享能力放入 `Provider*` / `Kit*` 包，
> 由宿主（`Factory*`）统一装配；跨插件互相引用会破坏插件的独立装配与卸载。
