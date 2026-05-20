# SkillKit

可复用的 Skill 发现、元数据解析与 prompt 组装工具包。扫描项目 skill 目录、校验元数据、加载 `SKILL.md` 并为选中的 skill 构建 prompt 文本。

## Package

- Product: `SkillKit`
- Platform: macOS 14+
- Swift tools: 6.0

## Main Types

- `SkillMetadata`: decoded metadata and content path for one skill.
- `SkillScanner`: filesystem scanner for project skills.
- `SkillService`: actor-backed service with bounded in-memory caching.
- `SkillPromptBuilder`: builds prompt sections from selected skills.

## Expected Skill Shape

Skills are expected to provide metadata and markdown instructions, typically:

```text
metadata.json
SKILL.md
```

## Testing

From this package directory:

```sh
swift test
```

Tests cover metadata decoding, filesystem scanning, service caching, and prompt building.

## Host integration

Keep UI selection, plugin wiring, and conversation policy in the host app. Keep reusable scan, validation, and prompt assembly in this package.
