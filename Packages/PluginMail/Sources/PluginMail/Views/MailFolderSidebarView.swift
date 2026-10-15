import SwiftUI
import LumiUI
import KitMail

/// 文件夹树侧栏：账户分组 + 文件夹列表 + 未读徽标。
public struct MailFolderSidebarView: View {
    @LumiTheme private var theme: any LumiUITheme

    let accounts: [MailAccountConfig]
    let folders: [MailFolder]
    let selectedAccountID: UUID?
    let selectedFolderPath: String?
    let unreadCountProvider: (MailFolder) async -> Int
    let onSelectAccount: (UUID) -> Void
    let onSelectFolder: (MailFolder) -> Void

    @State private var unreadCounts: [String: Int] = [:]

    public init(
        accounts: [MailAccountConfig],
        folders: [MailFolder],
        selectedAccountID: UUID?,
        selectedFolderPath: String?,
        unreadCountProvider: @escaping (MailFolder) async -> Int,
        onSelectAccount: @escaping (UUID) -> Void,
        onSelectFolder: @escaping (MailFolder) -> Void
    ) {
        self.accounts = accounts
        self.folders = folders
        self.selectedAccountID = selectedAccountID
        self.selectedFolderPath = selectedFolderPath
        self.unreadCountProvider = unreadCountProvider
        self.onSelectAccount = onSelectAccount
        self.onSelectFolder = onSelectFolder
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            accountHeader
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(folders) { folder in
                        folderRow(folder)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .task(id: selectedAccountID) {
            await reloadUnreadCounts()
        }
        .task(id: folders.map(\.path)) {
            await reloadUnreadCounts()
        }
    }

    private var accountHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let account = accounts.first(where: { $0.id == selectedAccountID }) {
                Text(account.displayName.isEmpty ? account.email : account.displayName)
                    .font(.appBodyEmphasized)
                    .foregroundColor(theme.textPrimary)
                Text(account.email)
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)
            } else if let first = accounts.first {
                Text(first.displayName.isEmpty ? first.email : first.displayName)
                    .font(.appBodyEmphasized)
                    .foregroundColor(theme.textPrimary)
            } else {
                Text("邮件")
                    .font(.appBodyEmphasized)
                    .foregroundColor(theme.textPrimary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func folderRow(_ folder: MailFolder) -> some View {
        let isSelected = selectedFolderPath == folder.path
        return HStack(spacing: 8) {
            Image(systemName: folderIcon(folder.kind))
                .font(.appCaption)
                .foregroundColor(isSelected ? theme.primary : theme.textSecondary)
                .frame(width: 20)
            Text(folder.name)
                .font(.appBody)
                .foregroundColor(isSelected ? theme.textPrimary : theme.textSecondary)
                .lineLimit(1)
            Spacer()
            if let unread = unreadCounts[folder.path], unread > 0 {
                Text("\(unread)")
                    .font(.appCaption)
                    .foregroundColor(theme.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(
                        Capsule().fill(theme.primary.opacity(0.12))
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? theme.primary.opacity(0.10) : .clear)
        )
        .onTapGesture {
            onSelectFolder(folder)
        }
    }

    private func folderIcon(_ kind: MailFolderKind) -> String {
        switch kind {
        case .inbox: return "tray.full"
        case .sent: return "paperplane"
        case .drafts: return "pencil"
        case .trash: return "trash"
        case .junk: return "exclamationmark.triangle"
        case .archive: return "archivebox"
        case .all: return "mail.stack"
        case .other: return "folder"
        }
    }

    private func reloadUnreadCounts() async {
        var counts: [String: Int] = [:]
        for folder in folders {
            let count = await unreadCountProvider(folder)
            if count > 0 {
                counts[folder.path] = count
            }
        }
        unreadCounts = counts
    }
}
