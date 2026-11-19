import AppKit
import Foundation

extension VM {
    func loadScreenshotSets(forceRefresh: Bool = false) async {
        guard let localizationID = selectedLocalizationID else { return }
        await runBusy(forceRefresh: forceRefresh) {
            let payload = try await client.loadScreenshotSets(localizationID: localizationID)
            // 请求期间可能已切到其它本地化：迟到的截图集合不得覆盖当前选择（#435）。
            guard selectedLocalizationID == localizationID else {
                Self.logger.info("\(self.t)discarded stale screenshot sets for localization: \(localizationID)")
                return
            }
            try await applyScreenshotPayload(payload, expectedLocalizationID: localizationID)
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
        // await 期间可能已切到其它 set：旧 set 的列表只进缓存，不得覆盖当前展示（#435）。
        applyLoadedScreenshots(loaded, forSetID: set.id)
    }

    /// 截图列表落盘：缓存按 set 键入，但展示列表只在当前选中仍是同一 set 时更新（#435）。
    @discardableResult
    func applyLoadedScreenshots(_ loaded: [AppScreenshot], forSetID setID: String) -> Bool {
        screenshotsBySetID[setID] = loaded
        guard selectedScreenshotSet?.id == setID else { return false }
        screenshots = loaded
        return true
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
            // 创建期间可能已切到其它本地化：迟到的新集合不得混进当前视图（#435）。
            guard selectedLocalizationID == localizationID else {
                Self.logger.info("\(self.t)discarded stale created screenshot set for localization: \(localizationID)")
                return
            }
            screenshotSets.append(set)
            if set.screenshotDisplayType == selectedScreenshotDisplayType {
                screenshotsBySetID[set.id] = []
                try await loadScreenshots()
            }
        }
    }

    /// 载入截图集合负载；本地化已切走时整体丢弃，不得写任何状态（#435）。
    func applyScreenshotPayload(_ payload: ScreenshotSetsPayload, expectedLocalizationID: String) async throws {
        guard selectedLocalizationID == expectedLocalizationID else {
            Self.logger.info("\(self.t)discarded stale screenshot payload for localization: \(expectedLocalizationID)")
            return
        }
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

        prefetchScreenshotPreviews()
    }

    func reloadScreenshotSetsFromNetwork() async throws {
        guard let localizationID = selectedLocalizationID else { return }
        try await applyScreenshotPayload(
            try await client.loadScreenshotSets(localizationID: localizationID),
            expectedLocalizationID: localizationID
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
