# Plugin Testing Conventions

- Each top-level plugin under `LumiApp/Plugins` gets a matching `Tests/<PluginName>Tests/` directory.
- `CoreTests/` is reserved for cross-plugin core logic and utilities, not plugin-specific behavior.
- New plugin work should add at least:
  - one metadata/smoke test for plugin registration shape
  - one pure-logic or view-model test that does not depend on UI rendering
- Bug fixes should add a regression test in the owning plugin test directory.
- Prefer testing:
  - pure logic helpers
  - stores and view models
  - service behavior behind protocols
  - plugin gating and registration decisions
- Avoid starting with heavyweight app-hosted integration tests unless the logic cannot be isolated.
