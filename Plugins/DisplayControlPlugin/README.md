# DisplayControlPlugin

External display DDC (Display Data Channel) control for Lumi.

- Brightness, Volume, Contrast control for external monitors via DDC/CI (VCP commands over I2C)
- Built-in display brightness via DisplayServices
- Apple Silicon DDC service matching (Arm64DDCMatcher)
- Debounced writes (150ms) to prevent DDC overload
- Unsupported controls are automatically disabled

Based on reference implementation from [hagimi-monitor](https://github.com/Acerola-1/hagimi-monitor).
