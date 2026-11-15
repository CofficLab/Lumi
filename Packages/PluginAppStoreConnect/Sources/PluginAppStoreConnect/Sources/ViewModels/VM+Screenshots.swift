import AppKit
import Foundation

extension VM {
    func loadScreenshotSets(forceRefresh: Bool = false) async {
        guard let localizationID = selectedLocalizationID else { return }
        await runBusy(forceRefresh: forceRefresh) {
            try await applyScreenshotPayload(
                try await client.loadScreenshotSets(localizationID: localizationID),
                pruneImageCache: forceRefresh
            )
        }
    }

    /// 载入当前展示类型的截图。
    ///
    /// - Parameter forceRefresh: 上传/删除后必须传 `true`。此时内存字典里是变更前的列表，
    ///   直接返回它会让界面继续显示已删除的截图（或漏掉刚上传的截图），
    ///   即使调用方已经切到 networkOnly。
    func loadScreenshots(forceRefresh: Bool = false) async throws {
        guard let set = selectedScreenshotSet else {
            screenshots = []
            return
        }

        if !forceRefresh, let cached = screenshotsBySetID[set.id] {
            screenshots = cached
            return
        }

        let loaded = try await client.listScreenshots(screenshotSetID: set.id)
        screenshotsBySetID[set.id] = loaded
        screenshots = loaded
    }

    func reloadScreenshotsForSelectedDisplayType(forceRefresh: Bool = false) async {
        await runBusy(forceRefresh: forceRefresh) {
            try await loadScreenshots(forceRefresh: forceRefresh)
        }
    }

    func addScreenshotFiles(_ urls: [URL]) async {
        guard !isReadOnlyVersion else { return }
        let displayType = selectedScreenshotDisplayType
        let items = await Task.detached(priority: .userInitiated) {
            urls.map { Self.readScreenshotItem(url: $0, displayType: displayType) }
        }.value
        // 后台读取期间可能切到只读版本；写回前重新校验，避免旧请求污染新状态。
        guard !isReadOnlyVersion else { return }
        pendingScreenshots.append(contentsOf: items)
    }

    /// 在后台线程打开图片并校验像素尺寸，组装待上传条目。
    nonisolated static func readScreenshotItem(url: URL, displayType: String) -> PendingScreenshot {
        guard let image = NSImage(contentsOf: url),
              let representation = image.representations.first else {
            return PendingScreenshot(
                url: url,
                width: 0,
                height: 0,
                displayType: displayType,
                status: .invalid(AppStoreConnectLocalization.string("Not a readable image"))
            )
        }
        let width = representation.pixelsWide
        let height = representation.pixelsHigh
        return PendingScreenshot(
            url: url,
            width: width,
            height: height,
            displayType: displayType,
            status: validateScreenshot(width: width, height: height)
        )
    }

    func removeScreenshot(_ screenshot: PendingScreenshot) {
        guard !isReadOnlyVersion else { return }
        pendingScreenshots.removeAll { $0.id == screenshot.id }
    }

    func ensureScreenshotSet() async {
        guard let localizationID = selectedLocalizationID, !isReadOnlyVersion else { return }
        await runBusy {
            if screenshotSets.contains(where: { $0.screenshotDisplayType == selectedScreenshotDisplayType }) {
                return
            }
            let set = try await client.createScreenshotSet(
                localizationID: localizationID,
                displayType: selectedScreenshotDisplayType
            )
            screenshotSets.append(set)
            if set.screenshotDisplayType == selectedScreenshotDisplayType {
                screenshotsBySetID[set.id] = []
                try await loadScreenshots()
            }
        }
    }

    func applyScreenshotPayload(_ payload: ScreenshotSetsPayload, pruneImageCache: Bool = false) async throws {
        screenshotSets = payload.sets
        screenshotsBySetID = payload.screenshotsBySetID
        alignSelectedScreenshotDisplayType()
        try await loadScreenshots()

        if screenshots.isEmpty {
            for set in screenshotSets where screenshotsBySetID[set.id] == nil {
                let loaded = try await client.listScreenshots(screenshotSetID: set.id)
                if !loaded.isEmpty {
                    screenshotsBySetID[set.id] = loaded
                }
            }
            try await loadScreenshots()
        }

        if pruneImageCache {
            await pruneScreenshotImageCache()
        }
        prefetchScreenshotPreviews()
    }

    func reloadScreenshotSetsFromNetwork() async throws {
        guard let localizationID = selectedLocalizationID else { return }
        try await applyScreenshotPayload(
            try await client.loadScreenshotSets(localizationID: localizationID),
            pruneImageCache: true
        )
    }

    func defaultScreenshotDisplayTypesForSelectedPlatform() -> [String] {
        let platform = (selectedVersion?.platform ?? selectedApp?.platform ?? "IOS").uppercased()
        if let types = Self.screenshotDisplayTypesByPlatform[platform] {
            return types
        }
        return Self.fallbackScreenshotDisplayTypes
    }

    func alignSelectedScreenshotDisplayType() {
        guard selectedScreenshotSet == nil, let first = screenshotSets.first else { return }
        selectedScreenshotDisplayType = first.screenshotDisplayType
    }

    nonisolated static func validateScreenshot(width: Int, height: Int) -> PendingScreenshot.Status {
        guard width > 0, height > 0 else {
            return .invalid(AppStoreConnectLocalization.string("Image has no pixel size"))
        }
        guard width >= 320, height >= 320 else {
            return .invalid(AppStoreConnectLocalization.string("Image is too small"))
        }
        return .ready
    }

    private func pruneScreenshotImageCache() async {
        let keepingURLs = Set(
            screenshotsBySetID.values
                .flatMap { $0 }
                .compactMap(\.previewURL)
        )
        await ScreenshotImageCache.shared.pruneEntries(keepingURLs: keepingURLs)
    }

    private func prefetchScreenshotPreviews() {
        let items: [(url: URL, screenshotID: String?)] = screenshotsBySetID.values
            .flatMap { $0 }
            .compactMap { screenshot in
                guard let url = screenshot.previewURL else { return nil }
                return (url, screenshot.id)
            }
        guard !items.isEmpty else { return }
        Task.detached(priority: .utility) {
            await ScreenshotImageCache.shared.prefetch(urls: items)
        }
    }
}
