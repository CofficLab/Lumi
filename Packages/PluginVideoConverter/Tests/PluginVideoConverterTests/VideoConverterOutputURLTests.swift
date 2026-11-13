import Foundation
import Testing
@testable import PluginVideoConverter

/// 转换输出路径的安全契约（#378）。
///
/// 同格式转换（如 MP4 → MP4）若直接换扩展名会得到与输入完全相同的输出路径，
/// FFmpeg 拒绝读写同一文件，默认操作路径无法完成。输出 URL 必须永远不等于输入。
@Suite("VideoConverterOutputURL")
struct VideoConverterOutputURLTests {

    @Test("同格式 MP4 转换产出独立输出文件，不写回输入")
    func sameFormatMP4ProducesDistinctOutput() {
        let input = URL(fileURLWithPath: "/tmp/movies/movie.mp4")
        let output = VideoConverterViewModel.makeOutputURL(for: input, format: .mp4)
        #expect(output.path != input.path)
        #expect(output.lastPathComponent == "movie-converted.mp4")
        #expect(output.deletingLastPathComponent().path == input.deletingLastPathComponent().path)
    }

    @Test("不同格式转换保留原文件名，仅换扩展名")
    func differentFormatKeepsBaseName() {
        let input = URL(fileURLWithPath: "/tmp/movies/movie.mp4")
        let mov = VideoConverterViewModel.makeOutputURL(for: input, format: .mov)
        #expect(mov.lastPathComponent == "movie.mov")
        #expect(mov.path != input.path)

        let gif = VideoConverterViewModel.makeOutputURL(for: input, format: .gif)
        #expect(gif.lastPathComponent == "movie.gif")
    }

    @Test("大小写不同的同格式扩展名也不写回输入（macOS 大小写不敏感卷）")
    func caseInsensitiveSameExtensionAvoidsInput() {
        let input = URL(fileURLWithPath: "/tmp/movies/movie.MP4")
        let output = VideoConverterViewModel.makeOutputURL(for: input, format: .mp4)
        #expect(output.path.caseInsensitiveCompare(input.path) != .orderedSame)
        #expect(output.lastPathComponent == "movie-converted.mp4")
    }

    @Test("任意格式的输出都不等于输入")
    func outputNeverEqualsInputForAnyFormat() {
        let inputs = [
            URL(fileURLWithPath: "/tmp/a.mp4"),
            URL(fileURLWithPath: "/tmp/b.MOV"),
            URL(fileURLWithPath: "/tmp/c.mkv"),
        ]
        for input in inputs {
            for format in VideoFormat.allCases {
                let output = VideoConverterViewModel.makeOutputURL(for: input, format: format)
                #expect(
                    output.path.caseInsensitiveCompare(input.path) != .orderedSame,
                    "format=\(format.rawValue) input=\(input.lastPathComponent) 输出与输入相同"
                )
            }
        }
    }

    @Test("输入名已含后缀时仍产出不同于输入的文件")
    func suffixedInputStillProducesDistinctOutput() {
        let input = URL(fileURLWithPath: "/tmp/movie-converted.mp4")
        let output = VideoConverterViewModel.makeOutputURL(for: input, format: .mp4)
        #expect(output.path != input.path)
        #expect(output.lastPathComponent == "movie-converted-converted.mp4")
    }
}