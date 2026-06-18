import AppKit
import Foundation

extension VM {
    var coverArtDisplayTypes: [String] {
        guard let app = selectedApp else { return Self.fallbackScreenshotDisplayTypes }
        return ScreenshotDisplaySpec.defaultDisplayTypes(forPlatform: app.platform)
    }

    var currentProjectPath: String {
        CoverArtRuntime.currentProjectPath
    }

    var hasOpenProject: Bool {
        !currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var selectedCoverArtManifest: CoverArtManifest? {
        guard let selectedCoverArtSlug else { return nil }
        return coverArtItems.first { $0.id == selectedCoverArtSlug }
    }

    func reloadCoverArtList(selecting slug: String? = nil) {
        guard let appID = selectedApp?.id else {
            coverArtItems = []
            selectedCoverArtSlug = nil
            coverArtHTML = ""
            coverArtFileURL = nil
            return
        }

        guard hasOpenProject else {
            coverArtItems = []
            selectedCoverArtSlug = nil
            coverArtHTML = ""
            coverArtFileURL = nil
            return
        }

        do {
            coverArtItems = try coverArtStore.list(projectPath: currentProjectPath, appID: appID)
            let targetSlug = slug
                ?? selectedCoverArtSlug
                ?? localStore.selectedCoverArtSlug(appID: appID)
                ?? coverArtItems.first?.id

            if let targetSlug, coverArtItems.contains(where: { $0.id == targetSlug }) {
                selectCoverArt(slug: targetSlug)
            } else {
                selectedCoverArtSlug = nil
                coverArtHTML = ""
                coverArtFileURL = nil
                localStore.setSelectedCoverArtSlug(nil, appID: appID)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectCoverArt(slug: String) {
        guard let appID = selectedApp?.id, hasOpenProject else { return }
        do {
            let document = try coverArtStore.read(projectPath: currentProjectPath, appID: appID, slug: slug)
            selectedCoverArtSlug = slug
            coverArtHTML = document.html
            coverArtFileURL = document.indexHTMLURL
            coverArtReloadToken = UUID()
            localStore.setSelectedCoverArtSlug(slug, appID: appID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createCoverArt(displayType: String, title: String, slug: String) {
        guard let appID = selectedApp?.id, hasOpenProject else { return }
        do {
            let document = try coverArtStore.create(
                projectPath: currentProjectPath,
                appID: appID,
                slug: slug,
                title: title,
                displayType: displayType
            )
            reloadCoverArtList(selecting: document.manifest.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func exportSelectedCoverArtPNG() async {
        guard let manifest = selectedCoverArtManifest,
              let app = selectedApp,
              !coverArtHTML.isEmpty else { return }

        guard let expectedSize = ScreenshotDisplaySpec.size(for: manifest.displayType) else {
            errorMessage = AppStoreConnectLocalization.string("Unknown screenshot display type: %@", manifest.displayType)
            return
        }

        do {
            let pngData = try await CoverArtHTMLExporter.exportPNG(
                html: coverArtHTML,
                fileURL: coverArtFileURL,
                expectedSize: expectedSize
            )

            let panel = NSSavePanel()
            panel.allowedContentTypes = [.png]
            panel.canCreateDirectories = true
            panel.isExtensionHidden = false
            let appName = app.name.replacingOccurrences(of: "/", with: "-")
            panel.nameFieldStringValue = "\(appName)_\(manifest.id)_\(manifest.displayType).png"
            if panel.runModal() == .OK, let url = panel.url {
                try pngData.write(to: url, options: .atomic)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshSelectedCoverArtFromDisk() {
        guard let slug = selectedCoverArtSlug else { return }
        selectCoverArt(slug: slug)
    }

    func suggestedCoverArtSlug(for title: String) -> String {
        let base = CoverArtSlugValidator.slug(from: title)
        guard coverArtItems.contains(where: { $0.id == base }) else { return base }
        var index = 2
        while coverArtItems.contains(where: { $0.id == "\(base)-\(index)" }) {
            index += 1
        }
        return "\(base)-\(index)"
    }
}
