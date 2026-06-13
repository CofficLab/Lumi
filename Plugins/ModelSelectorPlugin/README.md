# ModelSelectorPlugin

Independent Lumi plugin for LLM provider and model selection in the chat composer toolbar.

## Features

- **Composer toolbar button** — contributes via `chatSectionToolbarItems`
- **Model browser** — popover with provider tabs, search, frequent models, and auto routing
- **Persistence** — selections saved through `LumiChatServicing.selectProvider`
- **Agent tool** — `switch_model` for programmatic model switching

## Architecture

This plugin uses the new `LumiPlugin` system:

| Extension point | Purpose |
|-----------------|---------|
| `chatSectionToolbarItems` | Renders `ModelProviderPicker` in the composer toolbar |
| `agentTools` | Registers `SwitchModelTool` |

The chat shell (`ChatPanelPlugin`) renders plugin toolbar items from `ChatSectionCoordinator.chatSectionToolbarItems`, synced by `AppLayoutView`.

## Dependencies

| Package | Description |
|---------|-------------|
| `LumiCoreKit` | Plugin protocol, chat service types |
| `LumiUI` | Shared UI components |
| `AgentToolKit` | Agent tool bridge types |

## License

Proprietary. All rights reserved.
