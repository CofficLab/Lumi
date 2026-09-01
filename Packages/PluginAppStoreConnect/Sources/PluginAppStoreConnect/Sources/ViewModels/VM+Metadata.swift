import Foundation

extension VM {
    func loadLocalizations() async {
        guard let version = selectedVersion else { return }
        let preferredLocalizationID = selectedLocalizationID
        await runBusy {
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

    func selectLocalization(id: String) {
        selectedLocalizationID = id
        editedLocalization = localizations.first { $0.id == id }
        metadataIsDirty = false
        pendingScreenshots = []
        Task { await loadScreenshotSets() }
    }

    func markMetadataDirty() {
        metadataIsDirty = true
    }

    func saveMetadata() async {
        guard let editedLocalization, !isReadOnlyVersion else { return }
        await runBusy {
            let updated = try await client.updateLocalization(editedLocalization)
            if let index = localizations.firstIndex(where: { $0.id == updated.id }) {
                localizations[index] = updated
            }
            self.editedLocalization = updated
            metadataIsDirty = false
        }
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
                try await client.loadScreenshotSets(localizationID: localizationID),
                pruneImageCache: true
            )
        }
    }
}
