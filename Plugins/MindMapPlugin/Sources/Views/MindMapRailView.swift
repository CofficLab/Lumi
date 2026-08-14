import SwiftUI

/// 侧栏：按作用域列出思维导图，支持切换与删除。
struct MindMapRailView: View {
    @ObservedObject private var store = MindMapStore.shared

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $store.selectedScope) {
                ForEach(MindMapScope.allCases, id: \.self) { scope in
                    Text(scope.displayName()).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .padding(10)

            List(selection: Binding(
                get: { store.selectedMapId ?? "" },
                set: { newValue in
                    if let id = newValue.isEmpty ? nil : newValue {
                        try? store.selectMindMap(id: id, scope: store.selectedScope)
                    }
                }
            )) {
                ForEach(store.maps) { map in
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(map.title).lineLimit(1)
                            Text("\(map.nodes.count) nodes")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                    }
                    .tag(map.id)
                    .contextMenu {
                        Button(role: .destructive) {
                            store.deleteMindMap(id: map.id, scope: store.selectedScope)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()
            Button {
                _ = store.createMindMap(
                    title: MindMapLocalization.string("New Mind Map", "新思维导图"),
                    rootText: MindMapLocalization.string("Central Topic", "中心主题"),
                    direction: .bilateral,
                    scope: store.selectedScope
                )
            } label: {
                Label(MindMapLocalization.string("New Mind Map", "新思维导图"), systemImage: "plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
            .padding(10)
        }
    }
}
