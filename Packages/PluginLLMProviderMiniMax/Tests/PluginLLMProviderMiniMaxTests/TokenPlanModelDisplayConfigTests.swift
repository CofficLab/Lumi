import Foundation
import Testing
@testable import PluginLLMProviderMiniMax

/// `TokenPlanModelDisplayConfig` 的展示文案 key。
///
/// 这些 key 直接喂给 `pluginLocalization.string(_:)`，拼错不会编译失败，
/// 只会在 UI 上回落成原始 key（用户看到 `General model 5-hour call limit`）。
/// 因此这里既断言取值，也断言**每个 key 都真的存在于语言资源中**。
@Suite("配额展示配置")
struct TokenPlanModelDisplayConfigTests {

    private static let allConfigs: [TokenPlanModelDisplayConfig] = [.general, .video, .unknown]

    // MARK: - 取值

    @Test("常规模型映射到常规文案")
    func generalKeys() {
        let config = TokenPlanModelDisplayConfig.general

        #expect(config.displayNameKey == "General Model")
        #expect(config.intervalTitleKey == "5-Hour Window")
        #expect(config.intervalDescriptionKey == "General model 5-hour call limit")
    }

    @Test("视频模型映射到视频文案")
    func videoKeys() {
        let config = TokenPlanModelDisplayConfig.video

        #expect(config.displayNameKey == "Video Model")
        #expect(config.intervalTitleKey == "5-Hour Window")
        #expect(config.intervalDescriptionKey == "Video model 5-hour call limit")
    }

    @Test("未知模型回落到通用文案")
    func unknownKeys() {
        let config = TokenPlanModelDisplayConfig.unknown

        #expect(config.displayNameKey == "Unknown Model")
        // 未知模型不知道限额窗口长度，因此用中性的「当前时段」。
        #expect(config.intervalTitleKey == "Current Interval")
        #expect(config.intervalDescriptionKey == "Unknown Model")
    }

    // MARK: - 分类

    @Test("model_name 精确匹配才归为已知类型", arguments: [
        ("general", TokenPlanModelDisplayConfig.general),
        ("video", TokenPlanModelDisplayConfig.video),
        ("speech", TokenPlanModelDisplayConfig.unknown),
        ("general-preview", TokenPlanModelDisplayConfig.unknown),
        ("", TokenPlanModelDisplayConfig.unknown),
    ])
    func classifiesExactNamesOnly(name: String, expected: TokenPlanModelDisplayConfig) {
        #expect(TokenPlanModelDisplayConfig.from(name) == expected)
    }

    @Test("大小写不影响分类")
    func classificationIgnoresCase() {
        #expect(TokenPlanModelDisplayConfig.from("GENERAL") == .general)
        #expect(TokenPlanModelDisplayConfig.from("Video") == .video)
    }

    // MARK: - 与语言资源的契约

    @Test("所有展示 key 在简体中文下都能解析出翻译")
    func allKeysResolveInSimplifiedChinese() {
        // 显式指定 zh-Hans：若资源缺失，`string(_:locale:)` 会原样返回 key，
        // 而中文翻译与英文 key 不同，因此「不相等」即可证明命中。
        let zh = Locale(identifier: "zh-Hans")
        for config in Self.allConfigs {
            for key in [config.displayNameKey, config.intervalTitleKey, config.intervalDescriptionKey] {
                let localized = pluginLocalization.string(key, locale: zh)
                #expect(localized != key, "zh-Hans 资源缺少 key：\(key)")
            }
        }
    }

    @Test("所有展示 key 在繁体中文下都能解析出翻译")
    func allKeysResolveInTraditionalChinese() {
        let zh = Locale(identifier: "zh-TW")
        for config in Self.allConfigs {
            for key in [config.displayNameKey, config.intervalTitleKey, config.intervalDescriptionKey] {
                #expect(
                    pluginLocalization.string(key, locale: zh) != key,
                    "zh-TW 资源缺少 key：\(key)"
                )
            }
        }
    }

    @Test("配额字段文案 key 在四种中文里都能解析")
    func quotaFieldKeysResolveInAllChineseLocales() {
        let keys = [
            "MiniMax Token Plan", "MiniMax Token Plan Quota", "Loading...", "Refresh",
            "Authentication failed; please check your API Key", "Unable to fetch quota info",
            "Weekly Quota", "Unlimited calls", "Used %lld / %lld", "Resets in %@",
            "Updated at %@", "calls",
        ]

        for locale in ["zh-Hans", "zh-Hant", "zh-HK", "zh-TW"] {
            let loc = Locale(identifier: locale)
            for key in keys {
                #expect(
                    pluginLocalization.string(key, locale: loc) != key,
                    "\(locale) 资源缺少 key：\(key)"
                )
            }
        }
    }

    // MARK: - 展示口径

    @Test("视频模型的时段按调用次数计量，其余按百分比计量")
    func metricFollowsModelGranularity() {
        #expect(TokenPlanModelDisplayConfig.general.intervalMetric == .percent)
        #expect(TokenPlanModelDisplayConfig.general.weeklyMetric == .percent)
        #expect(TokenPlanModelDisplayConfig.video.intervalMetric == .count)
        #expect(TokenPlanModelDisplayConfig.video.weeklyMetric == .percent)
        #expect(TokenPlanModelDisplayConfig.unknown.intervalMetric == .percent)
    }

    @Test("每个模型都有独立图标")
    func eachModelHasIcon() {
        let icons = [
            TokenPlanModelDisplayConfig.general,
            .video,
            .unknown,
        ].map(\.iconName)

        #expect(Set(icons).count == icons.count)
        #expect(icons.allSatisfy { !$0.isEmpty })
    }

    @Test("剩余比例按展示口径换算：百分比取百分比，次数取剩余/上限")
    func remainingRatiosFollowMetric() {
        let general = TokenPlanData(
            modelName: "general",
            remainingPercent: 80,
            intervalStatus: 1,
            intervalTotal: 100,
            intervalUsage: 20,
            startTime: 0,
            endTime: 0,
            remainsTime: 0,
            weeklyRemainingPercent: 40,
            weeklyStatus: 1,
            weeklyTotal: 500,
            weeklyUsage: 10,
            weeklyStartTime: 0,
            weeklyEndTime: 0,
            weeklyRemainsTime: 0
        )
        let video = TokenPlanData(
            modelName: "video",
            remainingPercent: 0,
            intervalStatus: 1,
            intervalTotal: 20,
            intervalUsage: 5,
            startTime: 0,
            endTime: 0,
            remainsTime: 0,
            weeklyRemainingPercent: 0,
            weeklyStatus: 1,
            weeklyTotal: 0,
            weeklyUsage: 0,
            weeklyStartTime: 0,
            weeklyEndTime: 0,
            weeklyRemainsTime: 0
        )

        let generalRatios = TokenPlanModelDisplayConfig.general.remainingRatios(for: general)
        #expect(generalRatios.count == 2)
        #expect(generalRatios.contains { abs($0 - 0.8) < 0.0001 })
        #expect(generalRatios.contains { abs($0 - 0.4) < 0.0001 })

        // 视频模型时段是次数口径：剩余 15 / 20 = 0.75；本周无次数上限则不参与。
        let videoRatios = TokenPlanModelDisplayConfig.video.remainingRatios(for: video)
        #expect(videoRatios.count == 2)
        #expect(videoRatios.contains { abs($0 - 0.75) < 0.0001 })
    }

    @Test("次数口径在无上限时不产生比例")
    func countMetricWithoutLimitHasNoRatio() {
        let video = TokenPlanData(
            modelName: "video",
            remainingPercent: 0,
            intervalStatus: 1,
            intervalTotal: 0,
            intervalUsage: 0,
            startTime: 0,
            endTime: 0,
            remainsTime: 0,
            weeklyRemainingPercent: 0,
            weeklyStatus: 1,
            weeklyTotal: 0,
            weeklyUsage: 0,
            weeklyStartTime: 0,
            weeklyEndTime: 0,
            weeklyRemainsTime: 0
        )

        let ratios = TokenPlanModelDisplayConfig.video.remainingRatios(for: video)

        #expect(ratios.count == 1)
        #expect(abs(ratios[0]) < 0.0001)
    }
}
