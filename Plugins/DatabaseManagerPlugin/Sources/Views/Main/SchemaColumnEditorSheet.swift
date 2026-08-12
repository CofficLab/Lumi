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
            Text("Add Column").font(.title3.weight(.semibold))
            Form {
                TextField("Name", text: $name)
                TextField("Data Type", text: $dataType)
                Toggle("Allow NULL", isOn: $isNullable)
                TextField("Default SQL Expression", text: $defaultValue)
            }
            .formStyle(.grouped)
            if let errorMessage {
                Text(errorMessage).font(.appCaption).foregroundStyle(.red)
            }
            HStack {
                Spacer()
                AppButton("Cancel", style: .secondary, size: .small) { isPresented = false }
                AppButton("Stage Column", systemImage: "plus", style: .primary, size: .small) {
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
            Text("Rename Column").font(.title3.weight(.semibold))
            TextField("Name", text: $name)
            if let errorMessage {
                Text(errorMessage).font(.appCaption).foregroundStyle(.red)
            }
            HStack {
                Spacer()
                AppButton("Cancel", style: .secondary, size: .small) { dismiss() }
                AppButton("Stage Rename", style: .primary, size: .small) {
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
