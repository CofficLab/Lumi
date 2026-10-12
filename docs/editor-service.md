# Editor service implementation

`EditorService` is an internal SwiftPM target owned by `PluginCodeEditorHost`; it is not a standalone package or a separately exported product. Its implementation lives under `Packages/PluginCodeEditorHost/Sources/EditorService` and its tests live under `Packages/PluginCodeEditorHost/Tests/EditorServiceTests`.

The target implements the service facade, workbench/session state, language-server coordination, and adapters between the `ProviderEditor` contract and reusable `KitEditor*` packages. Other plugins extend editor capabilities through `ProviderEditor`; they must not depend on this internal target.

Run its tests from the Host package:

```sh
swift test --package-path Packages/PluginCodeEditorHost --filter EditorServiceTests
```

The package-level dependency map and extension lifecycle are documented in [the editor architecture guide](editor-architecture.md).
