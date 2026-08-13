import Foundation
import KernelLumi
import LumiUI
import os
import SuperLogKit
import SwiftUI

// MARK: - Plugin Entry

/// Image to PDF plugin.
///
/// Provides a view container that lets the user drop image files, convert
/// each one to a single-page PDF (with the page sized to the original image),
/// preview the produced PDFs, and finally export them to user-chosen
/// directory.
///
/// All real work lives in `ImageToPDFViewModel` and `ImageToPDFService`;
/// this file only wires the plugin into Lumi's host and contributes one
/// view container entry.
@MainActor
public final class ImageToPDFPlugin: LumiPlugin, SuperLog {
    public nonisolated static let emoji = "🖼️"
    public nonisolated static let verbose: Bool = false
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.image-to-pdf"
    )

    // MARK: - Plugin Identity

    public let id = "com.coffic.lumi.plugin.image-to-pdf"
    public var name: String {
        ImageToPDFLocalization.string("Image to PDF")
    }
    public let order = 875
    public let policy: LumiPluginPolicy = .optIn
    public let stage: LumiPluginStage = .beta

    public var pluginDescription: String {
        ImageToPDFLocalization.string(
            "Drop image files and convert each one to a single-page PDF."
        )
    }

    public init() {}

    // MARK: - Lifecycle

    public func onBoot(kernel: KernelLumi) async throws {
        // Mirror Projects / IdleTime plugins: use the kernel-provided plugin
        // data directory rather than a hard-coded Caches path. The view
        // model reads it from the runtime bridge on first conversion.
        ImageToPDFRuntimeBridge.directoryURL = kernel.storage?
            .pluginDataDirectory(for: "ImageToPDF")

        if Self.verbose {
            Self.logger.info("🖼️ ImageToPDFPlugin booted, stagingDir = \(ImageToPDFRuntimeBridge.directoryURL?.path ?? "<unavailable>")")
        }
    }

    public func onReady(kernel: KernelLumi) async throws {}

    // MARK: - View Container

    /// Contribute one view container that fills the entire workspace
    /// (rail / chat / panel chrome are all `.unsupported`).
    public func viewContainers(kernel: KernelLumi) -> [ViewContainerItem] {
        [
            ViewContainerItem(
                id: id,
                title: ImageToPDFLocalization.string("Image to PDF"),
                systemImage: "photo.on.rectangle.angled",
                railVisibility: .unsupported,
                chatVisibility: .unsupported,
                panelHeaderVisibility: .unsupported,
                panelBottomVisibility: .unsupported
            ) {
                ImageToPDFMainView()
            },
        ]
    }

    // MARK: - Plugin About

    public func pluginAboutView(kernel: KernelLumi) -> AnyView? {
        AnyView(ImageToPDFAboutView())
    }

    // MARK: - LumiPlugin Stubs

    public func llmProviders(kernel: KernelLumi) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: KernelLumi) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: KernelLumi) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: KernelLumi) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: KernelLumi) -> [LumiTitleToolbarItem] {
        [
            LumiTitleToolbarItem(
                id: "\(id).title",
                title: ImageToPDFLocalization.string("Image to PDF"),
                placement: .center,
                order: 200
            ) {
                ImageToPDFToolbarTitleView(
                    containerID: self.id,
                    kernel: kernel
                )
            },
        ]
    }
    public func panelHeaderItems(kernel: KernelLumi) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: KernelLumi) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: KernelLumi) -> [PanelRailTabItem] { [] }
    public func statusBarItems(kernel: KernelLumi) -> [StatusBarItem] { [] }
    public func chatSectionItems(kernel: KernelLumi) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: KernelLumi) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: KernelLumi) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: KernelLumi) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: KernelLumi) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: KernelLumi, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: KernelLumi) -> [AnyView] { [] }
    public func llmProviderSettingsItems(kernel: KernelLumi) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: KernelLumi) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: KernelLumi) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: KernelLumi) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: KernelLumi) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: KernelLumi, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: KernelLumi, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: KernelLumi) async {}
    public func configureEditorRuntime(kernel: KernelLumi) async {}
    public func agentTools(kernel: KernelLumi) -> [any LumiAgentTool] { [] }
}
