#!/usr/bin/env python3
"""Generate per-provider plugin packages (PluginLLMProviderXXX) under Packages/.

Each package mirrors one legacy LLM provider plugin:
  - Packages/PluginLLMProviderOpenAI/
      Package.swift
      Sources/PluginLLMProviderOpenAI/OpenAIProvider.swift   (copied from shared ProviderLLMVendors/Vendors)
      Sources/PluginLLMProviderOpenAI/OpenAIProviderPlugin.swift (SuperPlugin: onBoot registers itself)
      Tests/PluginLLMProviderOpenAITests/OpenAIProviderPluginTests.swift
"""
import os
import shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PKGS = os.path.join(ROOT, "Packages")
SHARED_VENDORS = os.path.join(PKGS, "ProviderLLMVendors", "Sources", "ProviderLLMVendors", "Vendors")

# package -> (displayName, legacyPluginID, [(typeName, vendorFile)])
PACKAGES = [
    ("PluginLLMProviderOpenAI", "OpenAI", "com.coffic.lumi.plugin.llm-provider.openai", [
        ("OpenAIProvider", "OpenAIProvider.swift"),
    ]),
    ("PluginLLMProviderAnthropic", "Anthropic", "com.coffic.lumi.plugin.llm-provider.anthropic", [
        ("AnthropicProvider", "AnthropicProvider.swift"),
    ]),
    ("PluginLLMProviderDeepSeek", "DeepSeek", "com.coffic.lumi.plugin.llm-provider.deepseek", [
        ("DeepSeekProvider", "DeepSeekProvider.swift"),
        ("DeepSeekAnthropicProvider", "DeepSeekAnthropicProvider.swift"),
    ]),
    ("PluginLLMProviderOpenRouter", "OpenRouter", "com.coffic.lumi.plugin.llm-provider.openrouter", [
        ("OpenRouterProvider", "OpenRouterProvider.swift"),
    ]),
    ("PluginLLMProviderZhipu", "Zhipu", "com.coffic.lumi.plugin.llm-provider.zhipu", [
        ("ZhipuProvider", "ZhipuProvider.swift"),
        ("ZhipuCodingPlanProvider", "ZhipuCodingPlanProvider.swift"),
    ]),
    ("PluginLLMProviderStepFun", "StepFun", "com.coffic.lumi.plugin.llm-provider.stepfun", [
        ("StepFunProvider", "StepFunProvider.swift"),
    ]),
    ("PluginLLMProviderMegaLLM", "MegaLLM", "com.coffic.lumi.plugin.llm-provider.megallm", [
        ("MegaLLMProvider", "MegaLLMProvider.swift"),
    ]),
    ("PluginLLMProviderHyperAPI", "HyperAPI", "com.coffic.lumi.plugin.llm-provider.hyperapi", [
        ("HyperAPIProvider", "HyperAPIProvider.swift"),
    ]),
    ("PluginLLMProviderAiRouter", "AiRouter", "com.coffic.lumi.plugin.llm-provider.airouter", [
        ("AiRouterProvider", "AiRouterProvider.swift"),
    ]),
    ("PluginLLMProviderAliyun", "Aliyun", "com.coffic.lumi.plugin.llm-provider.aliyun", [
        ("AliyunProvider", "AliyunProvider.swift"),
        ("AliyunTokenPlanProvider", "AliyunTokenPlanProvider.swift"),
    ]),
    ("PluginLLMProviderFeifeimiao", "Feifeimiao", "com.coffic.lumi.plugin.llm-provider.feifeimiao", [
        ("FeifeimiaoProvider", "FeifeimiaoProvider.swift"),
    ]),
    ("PluginLLMProviderFlyMux", "FlyMux", "com.coffic.lumi.plugin.llm-provider.flymux", [
        ("FlyMuxProvider", "FlyMuxProvider.swift"),
    ]),
    ("PluginLLMProviderHappyCode", "HappyCode", "com.coffic.lumi.plugin.llm-provider.happycode", [
        ("HappyCodeProvider", "HappyCodeProvider.swift"),
    ]),
    ("PluginLLMProviderKimiCode", "KimiCode", "com.coffic.lumi.plugin.llm-provider.kimicode", [
        ("KimiCodeProvider", "KimiCodeProvider.swift"),
        ("KimiCodeAnthropicProvider", "KimiCodeAnthropicProvider.swift"),
    ]),
    ("PluginLLMProviderLPgpt", "LPgpt", "com.coffic.lumi.plugin.llm-provider.lpgpt", [
        ("LPgptProvider", "LPgptProvider.swift"),
    ]),
    ("PluginLLMProviderMiniMax", "MiniMax", "com.coffic.lumi.plugin.llm-provider.minimax", [
        ("MiniMaxOpenAIProvider", "MiniMaxProviders.swift"),
        ("MiniMaxAnthropicProvider", "MiniMaxProviders.swift"),
        ("MiniMaxResponsesProvider", "MiniMaxProviders.swift"),
    ]),
    ("PluginLLMProviderOpenCode", "OpenCode", "com.coffic.lumi.plugin.llm-provider.opencode", [
        ("OpenCodeProvider", "OpenCodeProvider.swift"),
    ]),
    ("PluginLLMProviderSublyx", "Sublyx", "com.coffic.lumi.plugin.llm-provider.sublyx", [
        ("SublyxProvider", "SublyxProvider.swift"),
    ]),
    ("PluginLLMProviderXybbz", "Xybbz", "com.coffic.lumi.plugin.llm-provider.xybbz", [
        ("XybbzProvider", "XybbzProvider.swift"),
    ]),
    ("PluginLLMProviderXiaomi", "Xiaomi", "com.coffic.lumi.plugin.llm-provider.xiaomi", [
        ("XiaomiProvider", "XiaomiProvider.swift"),
        ("XiaomiAPIProvider", "XiaomiAPIProvider.swift"),
    ]),
]

PACKAGE_SWIFT_TEMPLATE = '''// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "{pkg}",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "{pkg}", targets: ["{pkg}"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../ProviderLLMVendors"),
    ],
    targets: [
        .target(
            name: "{pkg}",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "ProviderLLMVendors", package: "ProviderLLMVendors"),
            ],
            path: "Sources/{pkg}"
        ),
        .testTarget(
            name: "{pkg}Tests",
            dependencies: [
                "{pkg}",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
            ],
            path: "Tests/{pkg}Tests"
        ),
    ]
)
'''

PLUGIN_TEMPLATE = '''import Foundation
import KernelCore
import ProviderLLMManager

/// {display} 供应商装配插件（KernelCore 生态）。
///
/// 在 `onBoot` 中把本供应商的 {types} 注册进
/// `LLMProviderManagerProviding`，聊天链路即可经管理器路由到该供应商。
/// 对应旧版 {legacy} 的 `llmProviders(kernel:)` 贡献职责。
@MainActor
public final class {plugin}: SuperPlugin {{
    public let id = "{legacy_id}"
    public let order = 100

    public init() {{}}

    public func onBoot(kernel: KernelCoreContainer) throws {{
        guard let manager = kernel.resolveProvider((any LLMProviderManagerProviding).self) else {{
            return
        }}
        let providers: [any ManagedLLMProvider] = [{instances}]
        for provider in providers {{
            try? manager.register(provider)
        }}
    }}
}}
'''

TEST_TEMPLATE = '''import Foundation
import KernelCore
import ProviderLLMManager
import Testing
@testable import {pkg}

@MainActor
struct {plugin}Tests {{

    @Test("onBoot 把 {display} 供应商注册进管理器")
    func pluginRegistersProviders() throws {{
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMProviderManagerProviding()
        try kernel.registerProvider((any LLMProviderManagerProviding).self, manager)

        let plugin = {plugin}()
        try plugin.onBoot(kernel: kernel)

        #expect(manager.providerCount == {count})
        {checks}
    }}
}}
'''


def generate():
    total_providers = 0
    for pkg, display, legacy_id, entries in PACKAGES:
        # unique vendor files for this package
        vendor_files = sorted({vf for _, vf in entries})
        types = ", ".join(t for t, _ in entries)
        instances = ", ".join(f"{t}()" for t, _ in entries)
        plugin = f"{display}ProviderPlugin"

        src_dir = os.path.join(PKGS, pkg, "Sources", pkg)
        test_dir = os.path.join(PKGS, pkg, "Tests", f"{pkg}Tests")
        os.makedirs(src_dir, exist_ok=True)
        os.makedirs(test_dir, exist_ok=True)

        # 1. copy vendor implementations from shared package (add ProviderLLMVendors import)
        #    Idempotent: if the shared Vendors dir was already consumed, keep the
        #    implementation files already generated in each package.
        if os.path.isdir(SHARED_VENDORS):
            for vf in vendor_files:
                src = os.path.join(SHARED_VENDORS, vf)
                if not os.path.exists(src):
                    continue
                with open(src) as f:
                    content = f.read()
                if "import ProviderLLMVendors" not in content:
                    content = "import ProviderLLMVendors\n\n" + content
                with open(os.path.join(src_dir, vf), "w") as f:
                    f.write(content)

        # 2. Package.swift
        with open(os.path.join(PKGS, pkg, "Package.swift"), "w") as f:
            f.write(PACKAGE_SWIFT_TEMPLATE.format(pkg=pkg))

        # 3. Plugin.swift
        with open(os.path.join(src_dir, f"{plugin}.swift"), "w") as f:
            f.write(PLUGIN_TEMPLATE.format(
                display=display, types=types, legacy=legacy_id, plugin=plugin,
                legacy_id=legacy_id, instances=instances,
            ))

        # 4. Tests.swift
        checks = "\n        ".join(
            f'#expect(manager.provider(id: "{pid}")?.providerInfo.id == "{pid}")' for _, _, pid in entries
        )
        with open(os.path.join(test_dir, f"{plugin}Tests.swift"), "w") as f:
            f.write(TEST_TEMPLATE.format(pkg=pkg, plugin=plugin, display=display, count=len(entries), checks=checks))

        total_providers += len(entries)
        print(f"generated {pkg} ({len(entries)} providers)")

    print(f"total provider instances: {total_providers}")


if __name__ == "__main__":
    generate()
