import LumiUI
import SwiftUI

struct AddSchemaColumnSheet: View {
    @Binding var isPresented: Bool
    let onAdd: (NewTableColumnDraft) throws -> Void

    @State private var name = ""
    @State private var dataType = "TEXT"
    @State private var isNullable = true
    @State private var defaultValue = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(pluginLocalization.string("Add Column")).font(.title3.weight(.semibold))
            Form {
                TextField(pluginLocalization.string("Name"), text: $name)
                TextField(pluginLocalization.string("Data Type"), text: $dataType)
                Toggle(pluginLocalization.string("Allow NULL"), isOn: $isNullable)
                TextField(pluginLocalization.string("Default SQL Expression"), text: $defaultValue)
            }
            .formStyle(.grouped)
            if let errorMessage {
                Text(errorMessage).font(.appCaption).foregroundStyle(.red)
            }
            HStack {
                Spacer()
                AppButton(pluginLocalization.string("Cancel"), style: .secondary, size: .small) { isPresented = false }
                AppButton(pluginLocalization.string("Stage Column"), systemImage: "plus", style: .primary, size: .small) {
                    do {
                        try onAdd(NewTableColumnDraft(
                            name: name,
                            dataType: dataType,
                            isNullable: isNullable,
                            defaultValue: defaultValue.isEmpty ? nil : defaultValue
                        ))
                        isPresented = false
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}

struct RenameSchemaColumnSheet: View {
    let column: TableColumn
    let onRename: (String) throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var errorMessage: String?

    init(column: TableColumn, onRename: @escaping (String) throws -> Void) {
        self.column = column
        self.onRename = onRename
        self._name = State(initialValue: column.name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(pluginLocalization.string("Rename Column")).font(.title3.weight(.semibold))
            TextField(pluginLocalization.string("Name"), text: $name)
            if let errorMessage {
                Text(errorMessage).font(.appCaption).foregroundStyle(.red)
            }
            HStack {
                Spacer()
                AppButton(pluginLocalization.string("Cancel"), style: .secondary, size: .small) { dismiss() }
                AppButton(pluginLocalization.string("Stage Rename"), style: .primary, size: .small) {
                    do {
                        try onRename(name)
                        dismiss()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}

struct AddSchemaIndexSheet: View {
    @Binding var isPresented: Bool
    let availableColumns: [String]
    let onAdd: (NewTableIndexDraft) throws -> Void

    @State private var name = ""
    @State private var selectedColumns: Set<String> = []
    @State private var isUnique = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(pluginLocalization.string("Add Index")).font(.title3.weight(.semibold))
            TextField(pluginLocalization.string("Index Name"), text: $name)
            Toggle(pluginLocalization.string("Unique Index"), isOn: $isUnique)
            Text(pluginLocalization.string("Columns")).font(.appCaption).foregroundStyle(.secondary)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(availableColumns, id: \.self) { column in
                        Toggle(column, isOn: Binding(
                            get: { selectedColumns.contains(column) },
                            set: { selected in
                                if selected { selectedColumns.insert(column) }
                                else { selectedColumns.remove(column) }
                            }
                        ))
                    }
                }
            }
            .frame(maxHeight: 180)
            if let errorMessage { Text(errorMessage).font(.appCaption).foregroundStyle(.red) }
            HStack {
                Spacer()
                AppButton(pluginLocalization.string("Cancel"), style: .secondary, size: .small) { isPresented = false }
                AppButton(pluginLocalization.string("Stage Index"), systemImage: "plus", style: .primary, size: .small) {
                    do {
                        let ordered = availableColumns.filter(selectedColumns.contains)
                        try onAdd(NewTableIndexDraft(name: name, columns: ordered, isUnique: isUnique))
                        isPresented = false
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}
