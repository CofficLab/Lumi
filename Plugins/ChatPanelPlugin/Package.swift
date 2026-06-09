// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ChatPanelPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ChatPanelPlugin",
            targets: ["ChatPanelPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiChatKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/ChatInputEditorKit"),
        .package(path: "../../Plugins/ChatMiddlewarePlugin")
    ],
    targets: [
        .target(
            name: "ChatPanelPlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiChatKit", package: "LumiChatKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ChatInputEditorKit", package: "ChatInputEditorKit"),
                .product(name: "ChatMiddlewarePlugin", package: "ChatMiddlewarePlugin")
            ],
            path: ".",
            exclude: ["Tests", "README.md"],
            sources: [
                "Sources/ChatPanelPlugin.swift",
                "Sources/ChatPanelView.swift",
                "Sources/LocalStore.swift",
                "Sources/SplitWidthPersistence.swift",
                "Sources/Views/ChatAutomationLevelPicker.swift",
                "Sources/Views/ChatAttachmentPreviewView.swift",
                "Sources/Views/ChatAvailabilityView.swift",
                "Sources/Views/ChatCommandSuggestionsView.swift",
                "Sources/Views/ChatComposerView.swift",
                "Sources/Views/ChatScreenshotCapture.swift",
                "Sources/Views/ChatConversationListView.swift",
                "Sources/Views/ChatDivider.swift",
                "Sources/Views/ChatHeaderView.swift",
                "Sources/Views/ChatLanguagePicker.swift",
                "Sources/Views/ChatMessageBubble.swift",
                "Sources/Views/ChatMessageListView.swift",
                "Sources/Views/ChatPendingMessagesView.swift",
                "Sources/Views/ChatProviderPicker.swift",
                "Sources/Views/ChatStatusBarViews.swift",
                "Sources/Views/ChatVerbosityPicker.swift",
                "Sources/Views/ModelSelector/ChatModelSelectorModelRow.swift",
                "Sources/Views/ModelSelector/ChatModelSelectorSearchBar.swift",
                "Sources/Views/ModelSelector/ChatModelSelectorSidebar.swift",
                "Sources/Views/ModelSelector/ChatModelSelectorTab.swift",
                "Sources/Views/ModelSelector/ChatModelSelectorView.swift",
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "ChatPanelPluginTests",
            dependencies: ["ChatPanelPlugin"],
            path: "Tests"
        )
    ]
)
