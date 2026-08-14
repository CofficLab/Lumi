# Custom LLM Providers Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Allow users to add, edit, and remove custom cloud providers and models from Settings using OpenAI Chat Completions, Anthropic Messages, or OpenAI Responses protocols.

**Architecture:** Persist provider metadata and credentials separately, create a runtime provider backed by a protocol adapter, and extend the provider manager with reloadable custom registrations. The settings page will expose a top-level add button and a sheet form; model IDs are entered manually in the first version.

**Tech Stack:** SwiftUI, Swift Concurrency, existing KernelLumi provider protocols, LLMKit adapters, Keychain-backed API key storage, XCTest.

---

### Task 1: Add custom provider configuration and persistence

**Files:**
- Create: `Plugins/LLMProviderManagerPlugin/Sources/LLMProviderManagerPlugin/Models/CustomProviderConfiguration.swift`
- Create: `Plugins/LLMProviderManagerPlugin/Sources/LLMProviderManagerPlugin/Services/CustomProviderStore.swift`
- Test: `Plugins/LLMProviderManagerPlugin/Tests/CustomProviderStoreTests.swift`

Define protocol, provider metadata, model metadata, validation, Codable persistence, and Keychain API-key storage. Store only non-secret configuration in the plugin data directory and keep credentials out of UserDefaults.

### Task 2: Implement runtime providers for OpenAI and Anthropic protocols

**Files:**
- Create: `Plugins/LLMProviderManagerPlugin/Sources/LLMProviderManagerPlugin/Providers/CustomLLMProvider.swift`
- Modify: `Packages/KernelLumi/Sources/KernelLumi/Providers/LLMProviderManaging.swift`
- Test: `Plugins/LLMProviderManagerPlugin/Tests/CustomLLMProviderTests.swift`

Implement the existing `LumiLLMProvider` contract using the current OpenAI-compatible and Anthropic-compatible request/streaming helpers, with runtime metadata supplied by the saved configuration.

### Task 3: Add OpenAI Responses adapter

**Files:**
- Create: `Packages/LLMKit/Sources/LLMKit/Provider/OpenAIResponsesProviderAdapter.swift`
- Create: `Packages/LLMKit/Sources/LLMKit/Provider/OpenAIResponsesResponseModels.swift`
- Test: `Packages/LLMKit/Tests/OpenAIResponsesProviderAdapterTests.swift`

Support JSON and SSE responses, text output, tool calls, usage metadata, errors, and API-key authorization for the Responses endpoint.

### Task 4: Register and reload custom providers

**Files:**
- Modify: `Plugins/LLMProviderManagerPlugin/Sources/LLMProviderManagerPlugin/Managers/LLMProviderManager.swift`
- Modify: `Plugins/LLMProviderManagerPlugin/Sources/LLMProviderManagerPlugin/LLMProviderManagerPlugin.swift`

Load saved configurations at boot, register runtime providers, and expose add/update/remove operations that refresh settings and selection state without restarting the app.

### Task 5: Add settings UI

**Files:**
- Create: `Plugins/LLMProviderManagerPlugin/Sources/LLMProviderManagerPlugin/Views/Settings/AddCustomProviderSheet.swift`
- Modify: `Plugins/LLMProviderManagerPlugin/Sources/LLMProviderManagerPlugin/Views/Settings/ProviderSettingsPageBase.swift`
- Modify: `Plugins/LLMProviderManagerPlugin/Sources/LLMProviderManagerPlugin/Views/Settings/RemoteProviderSettingsPage.swift`

Add a top toolbar button, provider form, protocol selector, model editor, validation feedback, save/delete actions, and list refresh behavior.

### Task 6: Verify

Run focused package tests, plugin tests, and a macOS debug build. Check that existing built-in providers, API-key settings, and model selection remain unchanged.
