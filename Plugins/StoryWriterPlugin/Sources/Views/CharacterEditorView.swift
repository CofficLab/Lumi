import SwiftUI

/// Editor for a character card.
struct CharacterEditorView: View {
    @ObservedObject var viewModel: StoryWriterViewModel
    @State var character: Character

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "person.fill")
                        .font(.title)
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Character Name", text: $character.name)
                            .font(.title.bold())
                            .textFieldStyle(.plain)
                        Text("Last edited: \(character.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        Task {
                            await viewModel.deleteCharacter(id: character.id)
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }

                Divider()

                // Role
                VStack(alignment: .leading, spacing: 6) {
                    Text("Role")
                        .font(.headline)
                    TextField("e.g. Protagonist, Antagonist, Supporting...", text: $character.role)
                        .textFieldStyle(.roundedBorder)
                }

                // Personality
                VStack(alignment: .leading, spacing: 6) {
                    Text("Personality")
                        .font(.headline)
                    TextEditor(text: $character.personality)
                        .frame(minHeight: 80)
                        .border(.separator)
                }

                // Notes
                VStack(alignment: .leading, spacing: 6) {
                    Text("Notes")
                        .font(.headline)
                    TextEditor(text: $character.notes)
                        .frame(minHeight: 120)
                        .border(.separator)
                }

                Spacer()
            }
            .padding(20)
        }
        .onChange(of: character.name) { _, _ in saveCharacter() }
        .onChange(of: character.role) { _, _ in saveCharacter() }
        .onChange(of: character.personality) { _, _ in saveCharacter() }
        .onChange(of: character.notes) { _, _ in saveCharacter() }
    }

    private func saveCharacter() {
        Task {
            await viewModel.updateCharacter(character)
        }
    }
}
