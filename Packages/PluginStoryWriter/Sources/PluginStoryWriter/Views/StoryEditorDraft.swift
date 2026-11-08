import Foundation

/// 编辑器本地草稿：以父级传入的故事为基线，叠加尚未落盘的简介编辑。
/// 外部更新到达时只在本地没有未保存修改的情况下采纳新简介，
/// 保存时总是以最新基线重建，避免把整份旧 struct 写回覆盖外部更新。
struct StoryEditorDraft {
    private(set) var baseStory: Story
    private(set) var synopsis: String

    init(story: Story) {
        baseStory = story
        synopsis = story.synopsis
    }

    var hasUnsavedSynopsis: Bool {
        synopsis != baseStory.synopsis
    }

    mutating func applyExternalUpdate(_ incoming: Story) {
        let hadLocalEdits = hasUnsavedSynopsis
        baseStory = incoming
        if !hadLocalEdits {
            synopsis = incoming.synopsis
        }
    }

    /// 以最新外部版本为底稿，叠加本地未保存的简介（可选覆盖标题）。
    func storyToSave(title: String? = nil) -> Story {
        var story = baseStory
        story.synopsis = synopsis
        if let title {
            story.title = title
        }
        return story
    }

    mutating func markSaved(_ saved: Story) {
        baseStory = saved
        synopsis = saved.synopsis
    }

    mutating func updateSynopsis(_ value: String) {
        synopsis = value
    }
}
