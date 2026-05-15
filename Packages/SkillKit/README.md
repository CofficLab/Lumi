# SkillKit

Skill discovery, metadata parsing, and prompt assembly for Lumi.

`SkillKit` scans project skill directories, validates metadata, loads `SKILL.md` content, and builds prompt text for active skills.

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

The tests cover metadata decoding, filesystem scanning, service caching, and prompt building.

## App Integration

Keep UI selection, plugin wiring, and conversation policy in the app target. Keep reusable scan, validation, and prompt assembly behavior in this package.
