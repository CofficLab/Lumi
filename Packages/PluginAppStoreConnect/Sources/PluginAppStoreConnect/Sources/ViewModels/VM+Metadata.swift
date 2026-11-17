import Foundation

extension VM {
    func loadLocalizations() async {
        guard let version = selectedVersion else { return }
        let preferredLocalizationID = selectedLocalizationID
        await runBusy {
            let fetched = try await client.listLocalizations(versionID: version.id)
            // 请求期间可能已经切到别的版本或 App：迟到的本地化内容不能覆盖当前选择。
            guard selectedVersion?.id == version.id else {
                Self.logger.info("\(self.t)discarded stale localizations for version: \(version.id)")
                return
            }
            localizations = fetched
            if let preferredLocalizationID,
               localizations.contains(where: { $0.id == preferredLocalizationID }) {
                selectedLocalizationID = preferredLocalizationID
            } else if let primaryLocale = selectedApp?.primaryLocale,
                      let match = localizations.first(where: { $0.locale == primaryLocale }) {
                selectedLocalizationID = match.id
            } else {
                selectedLocalizationID = localizations.first?.id
            }
            editedLocalization = localizations.first { $0.id == selectedLocalizationID }
            metadataIsDirty = false
            if let localizationID = selectedLocalizationID {
                try await applyScreenshotPayload(
                    try await client.loadScreenshotSets(localizationID: localizationID)
                )
            }
        }
    }

    func selectLocalization(id: String) {
        selectedLocalizationID = id
        editedLocalization = localizations.first { $0.id == id }
        metadataIsDirty = false
        metadataEditGeneration += 1
        pendingScreenshots = []
        Task { await loadScreenshotSets() }
    }

    func markMetadataDirty() {
        metadataIsDirty = true
        metadataEditGeneration += 1
    }

    func saveMetadata() async {
        guard let editedLocalization, !isReadOnlyVersion else { return }
        let editGeneration = metadataEditGeneration
        await runBusy {
            let updated = try await client.updateLocalization(editedLocalization)
            applyMetadataSaveResponse(updated, forEditGeneration: editGeneration)
        }
    }

    /// 保存响应落盘。
    ///
    /// 保存 await 期间用户可能已切到其它本地化或继续编辑（#436）：响应只能
    /// 刷新列表里它保存的那一条；只有仍在编辑同一条且期间没有新编辑动作时，
    /// 才替换当前编辑态并清除未保存标记，绝不覆盖新内容或误清脏标记。
    func applyMetadataSaveResponse(
        _ updated: AppStoreVersionLocalization,
        forEditGeneration generation: Int
    ) {
        if let index = localizations.firstIndex(where: { $0.id == updated.id }) {
            localizations[index] = updated
        }
        guard selectedLocalizationID == updated.id,
              metadataEditGeneration == generation else { return }
        editedLocalization = updated
        metadataIsDirty = false
    }

    func reloadLocalizationsFromNetwork() async throws {
        guard let version = selectedVersion else { return }
        let preferredLocalizationID = selectedLocalizationID
        localizations = try await client.listLocalizations(versionID: version.id)
        if let preferredLocalizationID,
           localizations.contains(where: { $0.id == preferredLocalizationID }) {
            selectedLocalizationID = preferredLocalizationID
        } else if let primaryLocale = selectedApp?.primaryLocale,
                  let match = localizations.first(where: { $0.locale == primaryLocale }) {
            selectedLocalizationID = match.id
        } else {
            selectedLocalizationID = localizations.first?.id
        }
        editedLocalization = localizations.first { $0.id == selectedLocalizationID }
        metadataIsDirty = false
        if let localizationID = selectedLocalizationID {
            try await applyScreenshotPayload(
                try await client.loadScreenshotSets(localizationID: localizationID)
            )
        }
    }
}
