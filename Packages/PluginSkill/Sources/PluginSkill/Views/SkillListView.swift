import LumiUI
import ProviderSkill
import SwiftUI

/// Chat Toolbar 弹出的技能列表：复刻 PluginProjects.ListView 的 LumiUI 样式。
struct SkillListView: View {
    let skills: [SkillMetadata]

    @State private var searchText = ""

    private var filteredSkills: [SkillMetadata] {
        if searchText.isEmpty {
            return skills
        }
        return skills.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
            || $0.name.localizedCaseInsensitiveContains(searchText)
            || $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            list
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            AppSearchBar(
                text: $searchText,
                placeholder: LocalizedStringKey(pluginLocalization.string("Search"))
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var list: some View {
        if filteredSkills.isEmpty {
            if skills.isEmpty {
                AppEmptyState(
                    icon: "sparkles",
                    title: pluginLocalization.string("No Skills"),
                    description: pluginLocalization.string("No skills available for the current project.")
                )
                .frame(maxWidth: .infinity, minHeight: 126)
            } else {
                AppEmptyState(
                    icon: "magnifyingglass",
                    title: pluginLocalization.string("No Skills")
                )
                .frame(maxWidth: .infinity, minHeight: 126)
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filteredSkills) { skill in
                        SkillRowView(skill: skill)
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: 300)
        }
    }
}
