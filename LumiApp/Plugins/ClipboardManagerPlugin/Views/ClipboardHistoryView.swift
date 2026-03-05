import SwiftUI

struct ClipboardHistoryView: View {
    @StateObject private var viewModel = ClipboardManagerViewModel()
    @State private var selectedItemId: UUID?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header / Search
            HStack {
                GlassTextField(
                    title: "搜索",
                    text: $viewModel.searchText,
                    placeholder: "Search clipboard history..."
                )
                .onChange(of: viewModel.searchText) { _, _ in
                    viewModel.filterItems()
                }
                
                if !viewModel.searchText.isEmpty {
                    GlassButton(title: "Clear", style: .ghost) {
                        viewModel.searchText = ""
                    }
                }
            }
            .padding(10)
            .background(DesignTokens.Material.glass)
            .overlay(GlassDivider(), alignment: .bottom)
            
            // List
            if viewModel.items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 40))
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    Text("No clipboard records")
                        .font(.headline)
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selectedItemId) {
                    ForEach(viewModel.items) { item in
                        ClipboardItemRow(item: item)
                            .tag(item.id)
                            .contextMenu {
                                Button("Copy") {
                                    viewModel.copyToClipboard(item)
                                }
                                Button(item.isPinned ? "Unpin" : "Pin") {
                                    viewModel.togglePin(id: item.id)
                                }
                                Divider()
                                Button("Delete") {
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
                Text("\(viewModel.items.count) items")
                    .font(.caption)
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                Spacer()
                GlassButton(title: "Clear All", style: .danger) {
                    viewModel.clearAll()
                }
                .help("Clear History")
            }
            .padding(8)
            .background(DesignTokens.Material.glass)
            .overlay(GlassDivider(), alignment: .top)
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
                    .fill(DesignTokens.Material.glass)
                    .frame(width: 32, height: 32)
                
                Image(systemName: iconName(for: item.type))
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .lineLimit(2)
                    .font(.system(size: 13))
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                
                HStack {
                    if let appName = item.appName {
                        Text(appName)
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(DesignTokens.Color.semantic.textTertiary.opacity(0.15))
                            .cornerRadius(4)
                    }
                    
                    Text(item.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    
                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundColor(DesignTokens.Color.semantic.warning)
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

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .inRootView()
        .withDebugBar()
}
