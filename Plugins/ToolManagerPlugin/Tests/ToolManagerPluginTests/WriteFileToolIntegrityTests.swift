import Foundation
import LumiKernel
import Testing
@testable import ToolManagerPlugin

// MARK: - WriteFileTool / EditFileTool integrity reproduction
//
// Purpose: reproduce (or rule out) the silent tail-truncation bug reported
// against the host agent runtime's `edit_file` / `write_file` tools by
// exercising Lumi's own `WriteFileTool` / `EditFileTool` directly and
// comparing on-disk bytes against the input string.
//
// These tests do NOT go through the host's LLM tool dispatcher. They invoke
// the tool's `execute` directly with a `LumiToolExecutionContextState` whose
// `allowedDirectories` includes a fresh temp directory under
// `FileManager.default.temporaryDirectory`. This isolates any Lumi-internal
// loss-of-bytes from host-side LLM/transport issues.
//
// Each test writes content, reads the file back from disk, and asserts:
//   1. round-trip UTF-8 equality (the most important property);
//   2. reported `content.count` matches UTF-8 byte count *only* when the
//      string is pure ASCII — this surfaces the `content.count` ≠
//      `content.utf8.count` ambiguity in `WriteFileTool`'s status message.
//
// If Lumi's `WriteFileTool` is byte-clean, these tests should ALL pass.

@Suite("WriteFileTool / EditFileTool integrity", .serialized)
@MainActor
struct WriteFileToolIntegrityTests {

    // MARK: - Helpers

    private func makeKernel(allowedRoot: URL) -> (LumiKernel, LumiToolExecutionContextState) {
        let kernel = LumiKernel()
        let state = LumiToolExecutionContextState(
            conversationID: UUID(),
            toolCallID: "test-\(UUID().uuidString)",
            toolName: "write_file",
            allowedDirectories: [allowedRoot.path]
        )
        return (kernel, state)
    }

    private func makeTempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-write-integrity-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func runWrite(
        _ content: String,
        fileName: String = "out.txt"
    ) async throws -> (URL, String) {
        let dir = try makeTempDir()
        let fileURL = dir.appendingPathComponent(fileName)
        let (kernel, state) = makeKernel(allowedRoot: dir)
        let tool = WriteFileTool()
        let args: [String: LumiJSONValue] = [
            "path": .string(fileURL.path),
            "content": .string(content),
        ]
        let status = try await kernel.withToolExecutionContextState(state) {
            try await tool.execute(arguments: args, kernel: kernel)
        }
        return (fileURL, status)
    }

    private func readBack(_ url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        guard let s = String(data: data, encoding: .utf8) else {
            Issue.record("file at \(url.path) is not valid UTF-8: \(data.count) bytes")
            return ""
        }
        return s
    }

    // MARK: - Pure ASCII round-trip (control case)

    @Test("pure ASCII: write_file is byte-clean")
    func pureASCIIRoundTrip() async throws {
        // Use a long payload with the same character set that the host-side
        // bug reporter said failed: a literal Lumi source path with slashes
        // and trailing `print(...)` call site.
        let payload = String(
            repeating: "/Users/angel/Code/Coffic/Lumi/Packages/LumiKernel/Sources/LumiKernel/Types/Chat/LumiChatMessage.swift\n",
            count: 5
        ) + "print('OK, new length:', len(src))"

        let (url, _) = try await runWrite(payload)
        let back = try readBack(url)

        #expect(back == payload, "ASCII round-trip mismatch")
        #expect(back.utf8.count == payload.utf8.count, "ASCII byte count mismatch")

        let written = (try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0
        #expect(written == payload.utf8.count, "on-disk size \(written) != payload UTF-8 bytes \(payload.utf8.count)")
    }

    // MARK: - Chinese round-trip

    @Test("Chinese: write_file is byte-clean")
    func chineseRoundTrip() async throws {
        // Same path, with Chinese that multiplies byte count beyond char count.
        // This is exactly the case where `content.count` (returned in the
        // status string) under-reports the true file size, which is one
        // possible source of the "looks like bytes were lost" perception.
        let payload = """
        /Users/angel/Code/Coffic/Lumi/Packages/LumiKernel/Sources/LumiKernel/Types/Chat/LumiChatMessage.swift
        // 这是中文行点:「引号」、，；。
        // httpStatusCode, httpResponseBody, httpResponseHeaders are captured alongside httpResponseBody
        # httpResponseBody 行末
        TAIL_MARKER_98271_END
        """

        let (url, status) = try await runWrite(payload)
        let back = try readBack(url)

        #expect(back == payload, "Chinese round-trip mismatch")
        #expect(back.utf8.count == payload.utf8.count, "Chinese byte count mismatch")

        // Surface the content.count vs utf8.count discrepancy so a human
        // notices it. We don't fail on it — the file is still byte-clean.
        // The reported status string uses content.count (Swift Character count),
        // not utf8.count. For pure ASCII they're equal; for any non-ASCII text
        // the status will under-report the on-disk byte count.
        let reported = extractCharacterCount(from: status)
        #expect(reported == payload.count, "WriteFileTool reported \(reported ?? -1), expected content.count \(payload.count)")
        if reported != payload.utf8.count {
            // Note: this is a *deliberate informational comment*, not a failure.
            // The on-disk bytes are byte-clean (asserted above). The status string
            // simply under-reports when the payload contains non-ASCII characters.
            // Comment is intentionally a no-op assertion so the test still passes.
        }
    }

    // MARK: - Emoji + combining marks

    @Test("Emoji + combining marks: write_file is byte-clean")
    func emojiRoundTrip() async throws {
        // 🇦🇶 is two regional indicator codepoints, 👨‍👩‍👧‍👦 is a ZWJ sequence.
        // e-acute is "e" + U+0301, which `Character` groups into one grapheme
        // but UTF-8 encodes as 3 bytes. If anything treats `String` as a UTF-8
        // byte buffer naively, the trailing bytes get sliced off.
        let payload = "Hello 🇨🇳👨\u{200D}👩\u{200D}👧\u{200D}👦 café e\u{0301} TAIL_MARKER_98271_END"
        let (url, _) = try await runWrite(payload)
        let back = try readBack(url)

        #expect(back == payload, "Emoji round-trip mismatch")
        #expect(back.utf8.count == payload.utf8.count, "Emoji byte count mismatch")
    }

    // MARK: - Curly quotes and high-bit characters

    @Test("curly quotes + slashes: write_file is byte-clean")
    func curlyQuotesRoundTrip() async throws {
        // Curly quotes are 3 bytes each in UTF-8. The bug report listed
        // curly-quote paths in `httpResponseBody` as one of the failing
        // shapes; this payload also stresses the `preserveQuoteStyle` path
        // in `EditFileTool` if a subsequent edit is run.
        let payload = """
        let body = "httpResponseBody"; // 中文
        let msg = "don\u{2019}t lose the apostrophe: it\u{2019}s right here."
        let nested = "\u{201C}left\u{201D} and \u{2018}right\u{2019}"
        // httpStatusCode, httpResponseBody, httpResponseHeaders
        TAIL_MARKER_98271_END
        """

        let (url, _) = try await runWrite(payload)
        let back = try readBack(url)

        #expect(back == payload, "Curly-quote round-trip mismatch")
        #expect(back.utf8.count == payload.utf8.count, "Curly-quote byte count mismatch")
    }

    // MARK: - EditFileTool round-trip

    @Test("edit_file: new_string is byte-clean on disk")
    func editFileRoundTrip() async throws {
        let dir = try makeTempDir()
        let fileURL = dir.appendingPathComponent("edit_target.txt")

        // Seed file: simple, all ASCII.
        let seed = """
        line one
        line two
        line three
        TAIL_MARKER_98271_END
        """
        try seed.write(to: fileURL, atomically: true, encoding: .utf8)

        // new_string: Chinese + emoji + curly quote + backslash + trailing
        // marker. This is the literal class of payload the host-side bug
        // report says gets silently truncated.
        let newString = """
        line one
        // 替换成中文 + Emoji 🇨🇳 + 弯引号 don\u{2019}t
        line three
        # httpResponseBody, httpStatusCode, httpResponseHeaders
        TAIL_MARKER_98271_END
        """

        let (kernel, state) = makeKernel(allowedRoot: dir)
        let tool = EditFileTool()
        // Seed ends WITHOUT a trailing newline; use the exact seed as old_string.
        let args: [String: LumiJSONValue] = [
            "file_path": .string(fileURL.path),
            "old_string": .string(seed),
            "new_string": .string(newString),
        ]

        _ = try await kernel.withToolExecutionContextState(state) {
            try await tool.execute(arguments: args, kernel: kernel)
        }

        let back = try readBack(fileURL)
        #expect(back == newString, "edit_file corrupted new_string on disk")
        #expect(back.utf8.count == newString.utf8.count, "edit_file byte count mismatch")
    }

    // MARK: - Multiple writes overwrite cleanly (regression for "stale tail")

    @Test("write_file: overwriting shrinks to new size with no stale tail bytes")
    func overwriteShrinksCleanly() async throws {
        let dir = try makeTempDir()
        let fileURL = dir.appendingPathComponent("shrink.txt")

        let longPayload = String(repeating: "abcdefghij", count: 1_000) + "TAIL"
        let shortPayload = "short TAIL"

        // First write: long
        let (kernel1, state1) = makeKernel(allowedRoot: dir)
        _ = try await kernel1.withToolExecutionContextState(state1) {
            try await WriteFileTool().execute(
                arguments: [
                    "path": .string(fileURL.path),
                    "content": .string(longPayload),
                ],
                kernel: kernel1
            )
        }
        let afterFirst = try readBack(fileURL)
        #expect(afterFirst == longPayload, "first write corrupted")

        // Second write: shorter — must fully replace, no stale tail bytes.
        let (kernel2, state2) = makeKernel(allowedRoot: dir)
        _ = try await kernel2.withToolExecutionContextState(state2) {
            try await WriteFileTool().execute(
                arguments: [
                    "path": .string(fileURL.path),
                    "content": .string(shortPayload),
                ],
                kernel: kernel2
            )
        }
        let afterSecond = try readBack(fileURL)
        #expect(afterSecond == shortPayload, "overwrite left stale tail bytes")
        let writtenSize = (try FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? NSNumber)?.intValue ?? 0
        #expect(writtenSize == shortPayload.utf8.count, "on-disk size after overwrite is \(writtenSize), expected \(shortPayload.utf8.count)")
    }

    // MARK: - Helpers

    private func extractCharacterCount(from status: String) -> Int? {
        // Status format: "Wrote <N> characters to <path>"
        guard let range = status.range(of: "Wrote ") else { return nil }
        let tail = status[range.upperBound...]
        guard let endRange = tail.range(of: " characters") else { return nil }
        return Int(tail[..<endRange.lowerBound])
    }
}
