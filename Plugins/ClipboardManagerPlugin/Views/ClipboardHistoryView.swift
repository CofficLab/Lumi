import SwiftUI

struct ClipboardHistoryView: View {
    @StateObject private var viewModel = ClipboardManagerViewModel()
    @State private var selectedItemId: UUID?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header / Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索剪贴板历史...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .onChange(of: viewModel.searchText) { _ in
                        viewModel.filterItems()
                    }
                
                if !viewModel.searchText.isEmpty {
                    Button(action: { viewModel.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            .overlay(Divider(), alignment: .bottom)
            
            // List
            if viewModel.items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("暂无剪贴板记录")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selectedItemId) {
                    ForEach(viewModel.items) { item in
                        ClipboardItemRow(item: item)
                            .tag(item.id)
                            .contextMenu {
                                Button("复制") {
                                    viewModel.copyToClipboard(item)
                                }
                                Button(item.isPinned ? "取消置顶" : "置顶") {
                                    viewModel.togglePin(id: item.id)
                                }
                                Divider()
                                Button("删除") {
                                    viewModel.delete(id: item.id)
                                }
                            }
                            .onTapGesture(count: 2) {
                                viewModel.copyToClipboard(item)
                            }
                    }
                }
                .listStyle(.inset)
            }
            
            // Footer
            HStack {
                Text("\(viewModel.items.count) 个项目")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: { viewModel.clearAll() }) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("清空历史")
            }
            .padding(8)
            .background(Color(nsColor: .windowBackgroundColor))
            .overlay(Divider(), alignment: .top)
        }
        .onAppear {
            viewModel.refresh()
        }
    }
}

struct ClipboardItemRow: View {
    let item: ClipboardItem
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .frame(width: 32, height: 32)
                
                Image(systemName: iconName(for: item.type))
                    .foregroundColor(.secondary)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .lineLimit(2)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                
                HStack {
                    if let appName = item.appName {
                        Text(appName)
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(4)
                    }
                    
                    Text(item.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    func iconName(for type: ClipboardItemType) -> String {
        switch type {
        case .text: return "text.alignleft"
        case .image: return "photo"
        case .file: return "doc"
        case .html: return "chevron.left.forwardslash.chevron.right"
        case .color: return "paintpalette"
        }
    }
}
