import LumiUI
import SwiftUI

public struct ClipboardHistoryView: View {
    @StateObject private var viewModel = ClipboardManagerViewModel()
    @State private var selectedItemId: UUID?
    
    public var body: some View {
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
                    AppButton("Clear", style: .ghost, fillsWidth: true, action: { viewModel.searchText = "" })
                }
            }
            .padding(10)
            .background(Material.regularMaterial)
            .overlay(GlassDivider(), alignment: .bottom)
            
            // List
            if viewModel.items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 40))
                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                    Text(LumiPluginLocalization.string("No clipboard records", bundle: .module))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selectedItemId) {
                    ForEach(viewModel.items) { item in
                        ClipboardItemRow(item: item)
                            .tag(item.id)
                            .contextMenu {
                                Button(LumiPluginLocalization.string("Copy", bundle: .module)) {
                                    viewModel.copyToClipboard(item)
                                }
                                Button(item.isPinned ? "Unpin" : "Pin") {
                                    viewModel.togglePin(id: item.id)
                                }
                                Divider()
                                Button(LumiPluginLocalization.string("Delete", bundle: .module)) {
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
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                Spacer()
                AppButton("Clear All", style: .destructive, fillsWidth: true, action: { viewModel.clearAll() })
                .help(LumiPluginLocalization.string("Clear History", bundle: .module))
            }
            .padding(8)
            .background(Material.regularMaterial)
            .overlay(GlassDivider(), alignment: .top)
        }
        .onAppear {
            viewModel.refresh()
        }
    }
}

public struct ClipboardItemRow: View {
    public let item: ClipboardHistoryItem
    
    public var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Material.regularMaterial)
                    .frame(width: 32, height: 32)
                

                Image(systemName: iconName(for: ClipboardItemType(rawValue: item.type) ?? .text))
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))

//                Image(systemName: iconName(for: item.type))
//                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))

            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(item.content)
                    .lineLimit(2)
                    .font(.system(size: 13))
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                
                HStack {
                    if let appName = item.appName {
                        Text(appName)
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color(hex: "98989E").opacity(0.15))
                            .cornerRadius(4)
                    }
                    
                    Text(item.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                    
                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundColor(Color(hex: "FF9F0A"))
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    public func iconName(for type: ClipboardItemType) -> String {
        switch type {
        case .text: return "text.alignleft"
        case .image: return "photo"
        case .file: return "doc"
        case .html: return "chevron.left.forwardslash.chevron.right"
        case .color: return "paintpalette"
        }
    }
}
