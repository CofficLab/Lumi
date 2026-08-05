import Foundation
import LumiKernel
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

    public var pluginDescription: String {
        ImageToPDFLocalization.string(
            "Drop image files and convert each one to a single-page PDF."
        )
    }

    public init() {}

    // MARK: - Lifecycle

    public func onBoot(kernel: LumiKernel) async throws {
        // Mirror Projects / IdleTime plugins: use the kernel-provided plugin
        // data directory rather than a hard-coded Caches path. The view
        // model reads it from the runtime bridge on first conversion.
        ImageToPDFRuntimeBridge.directoryURL = kernel.storage?
            .pluginDataDirectory(for: "ImageToPDF")

        if Self.verbose {
            Self.logger.info("🖼️ ImageToPDFPlugin booted, stagingDir = \(ImageToPDFRuntimeBridge.directoryURL?.path ?? "<unavailable>")")
        }
    }

    public func onReady(kernel: LumiKernel) async throws {}

    // MARK: - View Container

    /// Contribute one view container that fills the entire workspace
    /// (rail / chat / panel chrome are all `.unsupported`).
    public func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] {
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

    public func pluginAboutView(kernel: LumiKernel) -> AnyView? {
        AnyView(ImageToPDFAboutView())
    }

    // MARK: - LumiPlugin Stubs

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: LumiKernel) -> [LumiTitleToolbarItem] {
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
    public func panelHeaderItems(kernel: LumiKernel) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: LumiKernel) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem] { [] }
    public func statusBarItems(kernel: LumiKernel) -> [StatusBarItem] { [] }
    public func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: LumiKernel) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: LumiKernel) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: LumiKernel) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: LumiKernel, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: LumiKernel) -> [AnyView] { [] }
    public func llmProviderSettingsItems(kernel: LumiKernel) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: LumiKernel) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: LumiKernel) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: LumiKernel) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: LumiKernel) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: LumiKernel, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: LumiKernel, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async {}
    public func configureEditorRuntime(kernel: LumiKernel) async {}
    public func agentTools(kernel: LumiKernel) -> [any LumiAgentTool] { [] }
}
