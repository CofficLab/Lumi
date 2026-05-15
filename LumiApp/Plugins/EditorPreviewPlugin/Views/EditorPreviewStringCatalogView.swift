import StringCatalogKit
import SwiftUI

struct EditorPreviewStringCatalogView: View {
    @EnvironmentObject private var themeVM: ThemeVM

    let catalog: StringCatalog
    @State private var selectedLanguageID: String?

    private var selectedLanguage: StringCatalog.Language {
        if let selectedLanguageID,
           let language = catalog.languages.first(where: { $0.id == selectedLanguageID }) {
            return language
        }
        return catalog.languages.first(where: { !$0.isSourceLanguage })
            ?? catalog.languages.first
            ?? StringCatalog.Language(
                id: catalog.sourceLanguage,
                displayName: catalog.sourceLanguage,
                completion: 0,
                translatedCount: 0,
                totalCount: 0,
                isSourceLanguage: true
            )
    }

    private var sourceLanguage: StringCatalog.Language {
        catalog.languages.first(where: { $0.id == catalog.sourceLanguage }) ?? selectedLanguage
    }

    var body: some View {
        HStack(spacing: 0) {
            languageSidebar
                .frame(width: 240)
            Divider()
            catalogTable
        }
        .background(themeVM.activeAppTheme.workspaceBackgroundColor())
        .onAppear {
            if selectedLanguageID == nil {
                selectedLanguageID = selectedLanguage.id
            }
        }
        .onChange(of: catalog.languages) { _, _ in
            guard let selectedLanguageID,
                  catalog.languages.contains(where: { $0.id == selectedLanguageID }) else {
                self.selectedLanguageID = selectedLanguage.id
                return
            }
        }
    }

    private var languageSidebar: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(catalog.languages) { language in
                    Button {
                        selectedLanguageID = language.id
                    } label: {
                        languageRow(language)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
        }
        .background(themeVM.activeAppTheme.workspaceBackgroundColor())
    }

    private func languageRow(_ language: StringCatalog.Language) -> some View {
        let isSelected = selectedLanguage.id == language.id
        let textColor = isSelected ? Color.white : themeVM.activeAppTheme.workspaceTextColor()
        let secondaryColor = isSelected ? Color.white.opacity(0.86) : themeVM.activeAppTheme.workspaceSecondaryTextColor()

        return HStack(spacing: 8) {
            Text(languageBadge(for: language.id))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(isSelected ? Color.accentColor : Color.white)
                .frame(width: 28, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected ? Color.white : Color.adaptive(light: "5D768A", dark: "4D6C82"))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(language.displayName)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(textColor)
                    .lineLimit(1)

                if language.isSourceLanguage {
                    Text(String(localized: "Default Localization", table: "EditorPreview"))
                        .font(.system(size: 11))
                        .foregroundColor(secondaryColor)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if !language.isSourceLanguage {
                Text(progressText(for: language))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(secondaryColor)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
    }

    private var catalogTable: some View {
        ScrollView([.horizontal, .vertical]) {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    ForEach(catalog.entries) { row in
                        catalogRow(row)
                    }
                } header: {
                    tableHeader
                }
            }
        }
        .background(themeVM.activeAppTheme.workspaceBackgroundColor())
    }

    private var tableHeader: some View {
        HStack(spacing: 0) {
            headerCell(String(localized: "Key", table: "EditorPreview"), width: 340)
            headerCell(sourceColumnTitle, width: 360)
            if selectedLanguage.id != sourceLanguage.id {
                headerCell(selectedLanguageColumnTitle, width: 360)
            }
        }
        .background(themeVM.activeAppTheme.workspaceBackgroundColor())
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func catalogRow(_ row: StringCatalog.Entry) -> some View {
        HStack(alignment: .top, spacing: 0) {
            valueCell(text: row.key, width: 340, isMissing: false)
            valueCell(
                text: row.valuesByLanguage[sourceLanguage.id]?.text ?? row.key,
                width: 360,
                isMissing: row.valuesByLanguage[sourceLanguage.id]?.text == nil
            )
            if selectedLanguage.id != sourceLanguage.id {
                valueCell(
                    text: row.valuesByLanguage[selectedLanguage.id]?.text ?? row.key,
                    width: 360,
                    isMissing: row.valuesByLanguage[selectedLanguage.id]?.text == nil
                )
            }
        }
        .background(rowBackground(for: row))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func headerCell(_ title: String, width: CGFloat) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(themeVM.activeAppTheme.workspaceTextColor())
            .lineLimit(1)
            .frame(width: width, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .overlay(alignment: .trailing) {
                Divider()
            }
    }

    private func valueCell(text: String, width: CGFloat, isMissing: Bool) -> some View {
        HighlightedStringCatalogText(text: text, isMissing: isMissing)
            .foregroundColor(isMissing ? themeVM.activeAppTheme.workspaceSecondaryTextColor().opacity(0.58) : themeVM.activeAppTheme.workspaceTextColor())
            .frame(width: width, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .overlay(alignment: .trailing) {
                Divider()
            }
    }

    private func rowBackground(for row: StringCatalog.Entry) -> Color {
        row.extractionState == "stale"
            ? Color.yellow.opacity(0.10)
            : Color.clear
    }

    private var sourceColumnTitle: String {
        String(
            format: String(localized: "Default Localization (%@)", table: "EditorPreview"),
            sourceLanguage.id
        )
    }

    private var selectedLanguageColumnTitle: String {
        "\(selectedLanguage.displayName) (\(selectedLanguage.id))"
    }

    private func progressText(for language: StringCatalog.Language) -> String {
        "\(Int((language.completion * 100).rounded()))%"
    }

    private func languageBadge(for languageID: String) -> String {
        let normalized = languageID.replacingOccurrences(of: "_", with: "-")
        let parts = normalized.split(separator: "-")
        if normalized.hasPrefix("zh-Hans") || normalized == "zh" {
            return "简"
        }
        if normalized.hasPrefix("zh-Hant") || normalized.hasPrefix("zh-HK") || normalized.hasPrefix("zh-TW") {
            return "中"
        }
        return String(parts.first?.prefix(2).uppercased() ?? normalized.prefix(2).uppercased())
    }
}

private struct HighlightedStringCatalogText: View {
    let text: String
    let isMissing: Bool

    var body: some View {
        Text(attributedText)
            .font(.system(size: 14))
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var attributedText: AttributedString {
        var result = AttributedString(text)
        guard !isMissing else {
            return result
        }

        for placeholder in StringCatalogPlaceholderScanner.placeholders(in: text) {
            let range = placeholder.range
            if let attributedRange = Range(range, in: result) {
                result[attributedRange].backgroundColor = Color.accentColor.opacity(0.28)
                result[attributedRange].foregroundColor = Color.accentColor
            }
        }
        return result
    }
}
