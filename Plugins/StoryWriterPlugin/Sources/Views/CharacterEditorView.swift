import SwiftUI

/// Editor for a character card.
struct CharacterEditorView: View {
    @ObservedObject var viewModel: StoryWriterViewModel
    @State var character: Character

    @Environment(\.locale) private var locale

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, locale: locale)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "person.fill")
                        .font(.title)
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 4) {
                        TextField(L("Character Name"), text: $character.name)
                            .font(.title.bold())
                            .textFieldStyle(.plain)
                        Text(String(
                            format: L("Last edited: %@"),
                            character.updatedAt.formatted(date: .abbreviated, time: .shortened)
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        Task {
                            await viewModel.deleteCharacter(id: character.id)
                        }
                    } label: {
                        Label(L("Delete"), systemImage: "trash")
                    }
                }

                Divider()

                // Role
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("Role"))
                        .font(.headline)
                    TextField(L("e.g. Protagonist, Antagonist, Supporting..."), text: $character.role)
                        .textFieldStyle(.roundedBorder)
                }

                // Personality
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("Personality"))
                        .font(.headline)
                    TextEditor(text: $character.personality)
                        .frame(minHeight: 80)
                        .border(.separator)
                }

                // Notes
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("Notes"))
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