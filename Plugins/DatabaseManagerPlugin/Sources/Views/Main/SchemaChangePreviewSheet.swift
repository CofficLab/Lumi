import LumiUI
import SwiftUI

struct SchemaChangePreviewSheet: View {
    @ObservedObject var viewModel: DatabaseViewModel
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Apply Structure Changes")
                        .font(.title3.weight(.semibold))
                    Text("Review the generated DDL before changing the database.")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button { isPresented = false } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain)
            }

            if viewModel.schemaChangeManager?.hasDestructiveChanges == true {
                Label("This change drops data and cannot be undone by Lumi.", systemImage: "exclamationmark.triangle.fill")
                    .font(.appCaption)
                    .foregroundStyle(.red)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(viewModel.schemaChangeManager?.changes ?? []) { change in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(change.summary)
                                .font(.appMicroEmphasized)
                            if let index = viewModel.schemaChangeManager?.changes.firstIndex(where: { $0.id == change.id }),
                               index < viewModel.pendingSchemaChangeSQL.count {
                                Text(viewModel.pendingSchemaChangeSQL[index])
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }

            HStack {
                Text("Some database engines auto-commit DDL statements.")
                    .font(.appMicro)
                    .foregroundStyle(.secondary)
                Spacer()
                AppButton("Cancel", style: .secondary, size: .small) { isPresented = false }
                AppButton("Apply Changes", systemImage: "checkmark.circle.fill", style: .primary, size: .small) {
                    isPresented = false
                    Task { await viewModel.saveSchemaChanges() }
                }
            }
        }
        .padding(20)
        .frame(minWidth: 620, minHeight: 440)
    }
}
