import Foundation

/// Incremental UTF-8 decoder for streaming text callbacks.
///
/// A multibyte character can be split across two `Data` chunks. Decoding each
/// chunk on its own with `String(data:encoding:.utf8)` returns nil for the
/// incomplete halves, silently dropping the character from the live text
/// callback even though the byte callback and the final aggregate keep it
/// (#172). This decoder retains the incomplete trailing bytes and joins them
/// with the next chunk, emitting only complete scalars. Genuinely invalid
/// bytes are replaced with U+FFFD so the stream never stalls; `flush()`
/// drains the residue at EOF.
final class StreamingUTF8Decoder: @unchecked Sendable {
    private static let replacement = Unicode.Scalar(0xFFFD)!

    private let lock = NSLock()
    private var pending = Data()

    /// Append `data` and return the complete scalars now available, keeping any
    /// incomplete trailing sequence for the next chunk. Returns nil when
    /// nothing complete is available yet.
    func decode(_ data: Data) -> String? {
        lock.lock()
        defer { lock.unlock() }
        pending.append(data)
        return drain(atEOF: false)
    }

    /// Drain remaining bytes at EOF. An incomplete trailing sequence can no
    /// longer be completed, so it is replaced rather than retained forever.
    func flush() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return drain(atEOF: true)
    }

    private func drain(atEOF: Bool) -> String? {
        let bytes = [UInt8](pending)
        var scalars = String.UnicodeScalarView()
        var index = 0

        while index < bytes.count {
            let lead = bytes[index]

            if lead < 0x80 {
                scalars.append(Unicode.Scalar(lead))
                index += 1
                continue
            }

            let length: Int
            let minimum: UInt32
            var value: UInt32
            if lead & 0xE0 == 0xC0 {
                length = 2; minimum = 0x80; value = UInt32(lead & 0x1F)
            } else if lead & 0xF0 == 0xE0 {
                length = 3; minimum = 0x800; value = UInt32(lead & 0x0F)
            } else if lead & 0xF8 == 0xF0 {
                length = 4; minimum = 0x10000; value = UInt32(lead & 0x07)
            } else {
                // Stray continuation byte or invalid lead (0xF8+).
                scalars.append(Self.replacement)
                index += 1
                continue
            }

            if index + length > bytes.count {
                // Incomplete trailing sequence: keep it for the next chunk,
                // unless this is EOF, where it can never be completed.
                if atEOF {
                    scalars.append(Self.replacement)
                    index = bytes.count
                }
                break
            }

            var valid = true
            for offset in 1..<length {
                let continuation = bytes[index + offset]
                if continuation & 0xC0 != 0x80 {
                    valid = false
                    break
                }
                value = (value << 6) | UInt32(continuation & 0x3F)
            }

            // Reject bad continuations, overlong encodings, surrogates and
            // out-of-range values; emit one replacement and resync at the next
            // byte so a corrupt stream never stalls.
            guard valid, value >= minimum, let scalar = Unicode.Scalar(value) else {
                scalars.append(Self.replacement)
                index += 1
                continue
            }

            scalars.append(scalar)
            index += length
        }

        if index > 0 {
            pending.removeFirst(index)
        }
        let text = String(scalars)
        return text.isEmpty ? nil : text
    }
}
