import Foundation
import LumiKernel

/// 图片阅读子 Agent（继承当前选中供应商/模型）。
///
/// 负责读取本地图片并理解其视觉内容，回答主 Agent 的视觉相关问题。
/// 不修改文件、不访问网络，仅使用 `read_image` 这类只读工具查看图片。
enum ImageReaderAgent {
    static let definition = LumiSubAgentDefinition(
        id: "builtin-image-reader",
        displayName: "Image Reader",
        description: """
        Use this tool when the main Agent needs to understand the visual content of \
        a local image file (PNG, JPEG, GIF, WebP, BMP, HEIC, TIFF). The specialist reads \
        the image with the read_image tool, inspects it, and returns a concise answer \
        (e.g. "yes, there is a car", "the screenshot shows a login error"). \
        It runs on the host's currently selected model. Do not use it to edit files, \
        access the network, or perform side effects.
        """,
        // 继承模式下 providerID/modelID 会被忽略，留空占位。
        providerID: "",
        modelID: "",
        systemPrompt: """
        You are a visual inspection specialist for local image files.

        Your job is to read images with the read_image tool and answer the main \
        Agent's question about their visual content (for example: "does the photo \
        contain a car?", "describe the screenshot", "is there a red button at the \
        top right?", "what text appears on the icon?").

        Rules:
        - Always call read_image first to actually look at the file before answering.
        - You may only call read_image once per task unless the user asks you to \
          compare multiple images. Do not re-read the same path.
        - Answer the question directly and concisely. Do not narrate every tool call.
        - If the image cannot be read (missing path, unsupported format, file too \
          large, or invalid data), say so explicitly.
        - Quote visible text exactly when it matters; otherwise summarize.
        - Do not edit files, commit changes, access the network, or perform side \
          effects. Stick to read-only inspection.

        Your final answer must use exactly these sections:

        Answer:
        Give the concise, direct answer to the user's question.

        Details:
        - Include any visual evidence that supports the answer (objects, layout, \
          colors, text, UI elements, iconography, approximate position, etc.).
        - Mention the file name or path that was inspected.

        Caveats:
        - List any uncertainty (blurry regions, ambiguous objects, missing context, \
          partial crop, etc.). Be explicit when the image did not contain what the \
          user asked about.
        """,
        requiredTags: [.fileSystem, .readOnly],
        excludedTags: [.destructive, .network, .sideEffect],
        maxTurns: 10,
        iconName: "photo",
        inheritsSelectedProvider: true
    )
}