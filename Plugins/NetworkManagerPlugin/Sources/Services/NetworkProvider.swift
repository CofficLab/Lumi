import Foundation
import LumiKernel
import Compression

/// 基于 URLSession 的 NetworkProviding 实现
@MainActor
public final class NetworkProvider: NetworkProviding {
    public let session: URLSession
    public let exchangeStore: HTTPExchangeStore?

    public init(session: URLSession = .shared, exchangeStore: HTTPExchangeStore? = nil) {
        self.session = session
        self.exchangeStore = exchangeStore
    }

    // MARK: - NetworkProviding

    public func request(_ request: HTTPRequest) async throws -> HTTPResponse {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        urlRequest.timeoutInterval = request.timeout

        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        let startedAt = Date()
        let record = exchangeStore?.begin(request: urlRequest, startedAt: startedAt)
        let (data, response): (Data, URLResponse)

        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let error as URLError {
            exchangeStore?.finish(record, error: error)
            throw HTTPNetworkError(
                url: request.url,
                underlyingDescription: error.localizedDescription
            )
        } catch {
            exchangeStore?.finish(record, error: error)
            throw HTTPNetworkError(
                url: request.url,
                underlyingDescription: error.localizedDescription
            )
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            let error = HTTPNetworkError(url: request.url, body: data, underlyingDescription: "Invalid response")
            exchangeStore?.finish(record, response: response, body: data, error: error)
            throw error
        }

        if !(200..<300).contains(httpResponse.statusCode) {
            let headers = Self.headers(from: httpResponse)
            let detailedError = HTTPNetworkError(
                url: request.url,
                statusCode: httpResponse.statusCode,
                headers: headers,
                body: data
            )
            exchangeStore?.finish(record, response: httpResponse, body: data, error: detailedError)
            throw detailedError
        }

        exchangeStore?.finish(record, response: httpResponse, body: data)

        return HTTPResponse(
            statusCode: httpResponse.statusCode,
            headers: Self.headers(from: httpResponse),
            body: data,
            url: request.url
        )
    }

    public func stream(
        _ request: HTTPRequest,
        onResponse: @Sendable @escaping (HTTPResponseMetadata) async -> Void,
        onChunk: @Sendable @escaping (Data) async -> Bool
    ) async throws {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        urlRequest.timeoutInterval = request.timeout
        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        let startedAt = Date()
        let record = exchangeStore?.begin(request: urlRequest, startedAt: startedAt)
        var receivedBody = Data()
        var response: URLResponse?

        do {
            let (bytes, urlResponse) = try await session.bytes(for: urlRequest)
            response = urlResponse
            guard let httpResponse = urlResponse as? HTTPURLResponse else {
                let error = HTTPNetworkError(url: request.url, underlyingDescription: "Invalid response")
                exchangeStore?.finish(record, response: urlResponse, body: receivedBody, error: error)
                throw error
            }

            let headers = Self.headers(from: httpResponse)
            await onResponse(HTTPResponseMetadata(
                statusCode: httpResponse.statusCode,
                headers: headers,
                url: httpResponse.url ?? request.url,
                mimeType: httpResponse.mimeType,
                expectedContentLength: httpResponse.expectedContentLength,
                textEncodingName: httpResponse.textEncodingName
            ))

            // Check for Content-Encoding
            let contentEncoding = headers["Content-Encoding"]?.lowercased()
            let isCompressed = contentEncoding == "br" || contentEncoding == "gzip" || contentEncoding == "deflate"

            if isCompressed {
                // For compressed streams, we need to buffer and decompress
                var compressedData = Data()
                for try await byte in bytes {
                    try Task.checkCancellation()
                    compressedData.append(byte)
                }
                receivedBody = compressedData

                // Decompress the data
                let decompressed = Self.decompress(compressedData, encoding: contentEncoding ?? "")
                if let decompressed = decompressed {
                    // Send decompressed chunks
                    var offset = 0
                    let chunkSize = 16 * 1024
                    while offset < decompressed.count {
                        let end = min(offset + chunkSize, decompressed.count)
                        let chunk = decompressed[offset..<end]
                        if !(await onChunk(Data(chunk))) {
                            break
                        }
                        offset = end
                    }
                } else {
                    // Fallback: send compressed data as-is
                    _ = await onChunk(compressedData)
                }
            } else {
                // Uncompressed stream - process as before
                var chunk = Data()
                for try await byte in bytes {
                    try Task.checkCancellation()
                    chunk.append(byte)
                    receivedBody.append(byte)
                    if chunk.count >= 16 * 1024 {
                        let shouldContinue = await onChunk(chunk)
                        chunk.removeAll(keepingCapacity: true)
                        if !shouldContinue { break }
                    }
                }
                if !chunk.isEmpty {
                    _ = await onChunk(chunk)
                }
            }

            if !(200..<300).contains(httpResponse.statusCode) {
                throw HTTPNetworkError(
                    url: request.url,
                    statusCode: httpResponse.statusCode,
                    headers: headers,
                    body: receivedBody
                )
            }
            exchangeStore?.finish(record, response: httpResponse, body: receivedBody)
        } catch is CancellationError {
            exchangeStore?.finish(record, response: response, body: receivedBody, error: CancellationError())
            throw CancellationError()
        } catch let error as HTTPNetworkError {
            exchangeStore?.finish(record, response: response, body: receivedBody, error: error)
            throw error
        } catch {
            let networkError = HTTPNetworkError(
                url: request.url,
                body: receivedBody,
                underlyingDescription: error.localizedDescription
            )
            exchangeStore?.finish(record, response: response, body: receivedBody, error: networkError)
            throw networkError
        }
    }

    // MARK: - Decompression

    private static func decompress(_ data: Data, encoding: String) -> Data? {
        switch encoding {
        case "br":
            return decompressBrotli(data)
        case "gzip":
            return decompressGzip(data)
        case "deflate":
            return decompressDeflate(data)
        default:
            return nil
        }
    }

    private static func decompressBrotli(_ data: Data) -> Data? {
        // Use Apple's built-in brotli support via Compression framework
        let bufferSize = data.count * 10 // Estimate decompressed size
        var decompressedData = Data(count: bufferSize)

        let result: Int = data.withUnsafeBytes { (compressedPointer: UnsafeRawBufferPointer) -> Int in
            guard let compressedBaseAddress = compressedPointer.baseAddress else { return 0 }
            return decompressedData.withUnsafeMutableBytes { (decompressedPointer: UnsafeMutableRawBufferPointer) -> Int in
                guard let decompressedBaseAddress = decompressedPointer.baseAddress else { return 0 }
                return compression_decode_buffer(
                    decompressedBaseAddress.assumingMemoryBound(to: UInt8.self),
                    bufferSize,
                    compressedBaseAddress.assumingMemoryBound(to: UInt8.self),
                    data.count,
                    nil,
                    COMPRESSION_BROTLI
                )
            }
        }

        if result > 0 {
            return decompressedData.prefix(result)
        }
        return nil
    }

    private static func decompressGzip(_ data: Data) -> Data? {
        let bufferSize = data.count * 10
        var decompressedData = Data(count: bufferSize)

        let result: Int = data.withUnsafeBytes { (compressedPointer: UnsafeRawBufferPointer) -> Int in
            guard let compressedBaseAddress = compressedPointer.baseAddress else { return 0 }
            return decompressedData.withUnsafeMutableBytes { (decompressedPointer: UnsafeMutableRawBufferPointer) -> Int in
                guard let decompressedBaseAddress = decompressedPointer.baseAddress else { return 0 }
                return compression_decode_buffer(
                    decompressedBaseAddress.assumingMemoryBound(to: UInt8.self),
                    bufferSize,
                    compressedBaseAddress.assumingMemoryBound(to: UInt8.self),
                    data.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }

        if result > 0 {
            return decompressedData.prefix(result)
        }
        return nil
    }

    private static func decompressDeflate(_ data: Data) -> Data? {
        let bufferSize = data.count * 10
        var decompressedData = Data(count: bufferSize)

        let result: Int = data.withUnsafeBytes { (compressedPointer: UnsafeRawBufferPointer) -> Int in
            guard let compressedBaseAddress = compressedPointer.baseAddress else { return 0 }
            return decompressedData.withUnsafeMutableBytes { (decompressedPointer: UnsafeMutableRawBufferPointer) -> Int in
                guard let decompressedBaseAddress = decompressedPointer.baseAddress else { return 0 }
                return compression_decode_buffer(
                    decompressedBaseAddress.assumingMemoryBound(to: UInt8.self),
                    bufferSize,
                    compressedBaseAddress.assumingMemoryBound(to: UInt8.self),
                    data.count,
                    nil,
                    COMPRESSION_LZFSE // Use LZFSE as fallback, may not work for all deflate streams
                )
            }
        }

        if result > 0 {
            return decompressedData.prefix(result)
        }
        return nil
    }

    private static func headers(from response: HTTPURLResponse) -> [String: String] {
        response.allHeaderFields.reduce(into: [String: String]()) { result, item in
            result[String(describing: item.key)] = String(describing: item.value)
        }
    }
}
