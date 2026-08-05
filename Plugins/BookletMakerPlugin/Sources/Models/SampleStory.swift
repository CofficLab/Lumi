import Foundation

// MARK: - Sample Story

/// 示意图使用的示例故事：共 8 页，每页内容不同，组合起来是一个完整的故事。
/// 用于在示意图区域演示拼版前后的页面顺序变化。
enum SampleStory {

    /// 示例故事的页数（也是示意图中输出纸张数的两倍）
    static let pageCount = 8

    /// 一页故事内容
    struct Page: Identifiable {
        /// 页码（1-based）
        var id: Int
        /// 页面装饰图标（emoji），让每页在缩略图上一眼可辨
        let icon: String
        /// 页面标题
        let title: String
        /// 正文（短句，适合小尺寸示意图展示）
        let body: String
    }

    /// 《小狐狸的星星灯》，共 8 页
    static let pages: [Page] = [
        Page(
            id: 1,
            icon: "🦊",
            title: "小狐狸的星星灯",
            body: """
            小狐狸阿布 著

            森林深处住着一只小狐狸，
            他叫阿布，最喜欢看星星。
            """
        ),
        Page(
            id: 2,
            icon: "🌲",
            title: "第一章 · 出发",
            body: """
            一天夜里，阿布发现
            天上的星星少了一颗。

            他决定提着小灯笼，
            去森林尽头寻找答案。
            """
        ),
        Page(
            id: 3,
            icon: "🦉",
            title: "第二章 · 猫头鹰",
            body: """
            老橡树上的猫头鹰说：
            「星星落进了月亮湖，
            变成了湖底的一盏灯。」
            """
        ),
        Page(
            id: 4,
            icon: "🌙",
            title: "第三章 · 月亮湖",
            body: """
            阿布跑到月亮湖边，
            湖水亮晶晶的。

            湖底真的有一点光，
            一闪一闪，像在打招呼。
            """
        ),
        Page(
            id: 5,
            icon: "🐸",
            title: "第四章 · 青蛙帮忙",
            body: """
            小青蛙扑通跳进湖里，
            把那颗星星托出水面。

            「拿去吧，」青蛙说，
            「它想家啦。」
            """
        ),
        Page(
            id: 6,
            icon: "⭐",
            title: "第五章 · 星星灯",
            body: """
            阿布把星星捧在手心，
            星星暖洋洋的，

            照亮了回家的路，
            也照亮了每一张笑脸。
            """
        ),
        Page(
            id: 7,
            icon: "🏔️",
            title: "第六章 · 回家",
            body: """
            阿布爬上最高的山坡，
            用力把星星抛向夜空。

            星星转了个圈，
            稳稳地挂回了天上。
            """
        ),
        Page(
            id: 8,
            icon: "🌟",
            title: "尾声",
            body: """
            从此，每当夜幕降临，
            天上都多了一颗特别亮的星。

            那是阿布的朋友，
            在对他眨眼睛。

            —— 完 ——
            """
        ),
    ]

    /// 按页码（1-based）取一页；越界时返回 nil
    static func page(_ number: Int) -> Page? {
        pages.first { $0.id == number }
    }
}
