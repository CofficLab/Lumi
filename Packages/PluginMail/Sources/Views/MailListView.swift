import SwiftUI
import LumiUI
import KitMail

/// 邮件列表：搜索框 + 未读加粗行 + 分页加载 + 下拉刷新。
public struct MailListView: View {
    @LumiTheme private var theme: any LumiUITheme

    let messages: [MailCacheItem.Summary]
    let selectedMessage: MailCacheItem.Summary?
    let isSyncing: Bool
    @Binding var searchQuery: String
    let onSelect: (MailCacheItem.Summary) -> Void
    let onRefresh: () -> Void
    let onLoadMore: () -> Void

    private var filtered: [MailCacheItem.Summary] {
        guard !searchQuery.isEmpty else { return messages }
        let q = searchQuery.lowercased()
        return messages.filter {
            $0.subject.lowercased().contains(q)
                || $0.fromEmail.lowercased().contains(q)
                || ($0.snippet?.lowercased().contains(q) ?? false)
        }
    }

    public init(
        messages: [MailCacheItem.Summary],
        selectedMessage: MailCacheItem.Summary?,
        isSyncing: Bool,
        searchQuery: Binding<String>,
        onSelect: @escaping (MailCacheItem.Summary) -> Void,
        onRefresh: @escaping () -> Void,
        onLoadMore: @escaping () -> Void
    ) {
        self.messages = messages
        self.selectedMessage = selectedMessage
        self.isSyncing = isSyncing
        self._searchQuery = searchQuery
        self.onSelect = onSelect
        self.onRefresh = onRefresh
        self.onLoadMore = onLoadMore
    }

    public var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            if isSyncing && messages.isEmpty {
                VStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在同步…")
                        .font(.appCaption)
                        .foregroundColor(theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filtered.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: searchQuery.isEmpty ? "tray" : "magnifyingglass")
                        .font(.system(size: 30))
                        .foregroundColor(theme.textTertiary)
                    Text(searchQuery.isEmpty ? "没有邮件" : "没有匹配「\(searchQuery)」的结果")
                        .font(.appBody)
                        .foregroundColor(theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filtered) { message in
                            row(message)
                            Divider()
                        }
                        if messages.count >= 50 {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .controlSize(.small)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                            .onAppear { onLoadMore() }
                        }
                    }
                }
                .refreshable {
                    onRefresh()
                }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.appCaption)
                .foregroundColor(theme.textTertiary)
            TextField("搜索邮件", text: $searchQuery)
                .textFieldStyle(.plain)
                .font(.appBody)
            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.appCaption)
                        .foregroundColor(theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func row(_ message: MailCacheItem.Summary) -> some View {
        let isSelected = selectedMessage?.uid == message.uid
        return HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(senderDisplayName(message))
                        .font(.appBody)
                        .fontWeight(message.isRead ? .regular : .bold)
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)
                    if message.hasAttachment {
                        Image(systemName: "paperclip")
                            .font(.appCaption)
                            .foregroundColor(theme.textTertiary)
                    }
                    Spacer()
                    Text(relativeDate(message.date))
                        .font(.appCaption)
                        .foregroundColor(theme.textTertiary)
                }
                Text(message.subject.isEmpty ? "（无主题）" : message.subject)
                    .font(.appBody)
                    .fontWeight(message.isRead ? .regular : .bold)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)
                if let snippet = message.snippet, !snippet.isEmpty {
                    Text(snippet)
                        .font(.appCaption)
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? theme.primary.opacity(0.10) : .clear)
        )
        .onTapGesture {
            onSelect(message)
        }
    }

    private func senderDisplayName(_ message: MailCacheItem.Summary) -> String {
        if let name = message.fromDisplayName, !name.isEmpty {
            return name
        }
        return message.fromEmail.isEmpty ? "未知发件人" : message.fromEmail
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}
