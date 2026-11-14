import LumiUI
import SwiftUI

/// Goal 详情弹窗：只读展示 + 内容编辑（#1332）。
///
/// 用于 SidebarHeader 中点击 info.circle 后的二级 popover。
/// 编辑只覆盖 title / description / successCriteria；保存经 `onSave` 写库，
/// 成功后由 GoalChangeCenter 驱动侧栏刷新。终态 Goal 不显示编辑入口。
struct GoalDescriptionPopoverContent: View {
    @LumiTheme private var theme

    let goal: GoalDisplayItem
    /// (title, description, successCriteria)；失败时抛出，错误就近展示。
    let onSave: @MainActor (String, String?, String?) async throws -> Void

    @State private var isEditing = false
    @State private var draftTitle = ""
    @State private var draftDescription = ""
    @State private var draftCriteria = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()
                .opacity(0.7)

            if isEditing {
                editFields
                Divider()
                    .opacity(0.7)
                footer
            } else {
                readContent
            }
        }
        .frame(width: 360, height: isEditing ? 400 : 260)
        .background(theme.background)
        .appThemedAppearance()
        .background {
            ThemeWindowAppearanceBridge()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: isEditing ? "pencil" : "text.alignleft")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(theme.primary)
                .frame(width: 28, height: 28)
                .background(
                    theme.primary.opacity(0.12),
                    in: Circle()
                )

            Text(pluginLocalization.string(isEditing ? "Edit goal" : "Goal details"))
                .font(.appCaptionEmphasized)
                .foregroundColor(theme.textPrimary)

            Spacer(minLength: 0)

            if !isEditing && !goal.isTerminal {
                Button {
                    beginEditing()
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(theme.textSecondary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(pluginLocalization.string("Edit goal"))
                .accessibilityLabel(pluginLocalization.string("Edit goal"))
                .accessibilityIdentifier(GoalAccessibility.descriptionEditButton)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Read

    private var readContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(goal.title)
                    .font(.headline)
                    .foregroundColor(theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier(GoalAccessibility.detailTitle)

                if let description = goal.goalDescription, !description.isEmpty {
                    section(label: pluginLocalization.string("Description")) {
                        Text(description)
                            .accessibilityIdentifier(GoalAccessibility.descriptionText)
                    }
                }

                if let criteria = goal.successCriteria, !criteria.isEmpty {
                    section(label: pluginLocalization.string("Success criteria")) {
                        Text(criteria)
                            .accessibilityIdentifier(GoalAccessibility.criteriaText)
                    }
                }
            }
            .padding(16)
        }
        .scrollIndicators(.automatic)
    }

    private func section(label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(theme.textSecondary)
            content()
                .font(.body)
                .foregroundColor(theme.textPrimary)
                .multilineTextAlignment(.leading)
                .lineSpacing(3)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Edit

    private var editFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            field(label: pluginLocalization.string("Title")) {
                TextField(pluginLocalization.string("Title"), text: $draftTitle)
                    .textFieldStyle(.plain)
                    .accessibilityIdentifier(GoalAccessibility.editTitleField)
            }

            field(label: pluginLocalization.string("Description")) {
                TextEditor(text: $draftDescription)
                    .frame(height: 96)
                    .accessibilityIdentifier(GoalAccessibility.editDescriptionField)
            }

            field(label: pluginLocalization.string("Success criteria")) {
                TextEditor(text: $draftCriteria)
                    .frame(height: 64)
                    .accessibilityIdentifier(GoalAccessibility.editCriteriaField)
            }
        }
        .padding(16)
    }

    private func field(label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(theme.textSecondary)
            content()
                .font(.body)
                .foregroundColor(theme.textPrimary)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(theme.textPrimary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
        }
    }

    // MARK: - Footer

    /// 底部确认区：保存 / 取消 + 失败原因。
    ///
    /// 错误就近展示而不是 toast / 关闭弹窗：保存失败时草稿仍在，
    /// 用户需要看清原因再决定重试还是放弃（与 fork 弹窗同一范式）。
    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier(GoalAccessibility.editError)
            }

            HStack {
                Button(pluginLocalization.string("Cancel")) {
                    isEditing = false
                    errorMessage = nil
                }
                .buttonStyle(.bordered)
                .disabled(isSaving)
                .accessibilityIdentifier(GoalAccessibility.editCancel)

                Spacer(minLength: 0)

                Button {
                    save()
                } label: {
                    Group {
                        if isSaving {
                            ProgressView()
                                .controlSize(.mini)
                        } else {
                            Text(pluginLocalization.string("Save"))
                        }
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(minWidth: 72)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving || draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier(GoalAccessibility.editSave)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Actions

    private func beginEditing() {
        draftTitle = goal.title
        draftDescription = goal.goalDescription ?? ""
        draftCriteria = goal.successCriteria ?? ""
        errorMessage = nil
        isEditing = true
    }

    private func save() {
        guard !isSaving else { return }
        errorMessage = nil
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                // 空白归一化（trim / 空串转 nil）由存储层统一处理
                try await onSave(draftTitle, draftDescription, draftCriteria)
                isEditing = false
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}