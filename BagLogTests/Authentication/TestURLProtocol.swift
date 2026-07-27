import Foundation
import Synchronization

final class TestURLProtocol: URLProtocol {
    struct Stub: Sendable {
        let statusCode: Int
        let data: Data
        let headers: [String: String]
        let errorCode: URLError.Code?

        init(
            statusCode: Int = 200,
            data: Data = Data(),
            headers: [String: String] = [:],
            errorCode: URLError.Code? = nil
        ) {
            self.statusCode = statusCode
            self.data = data
            self.headers = headers
            self.errorCode = errorCode
        }
    }

    private static let responses = Mutex<[Stub]>([Stub()])
    private static let recordedRequests = Mutex<[URLRequest]>([])

    static func configure(
        statusCode: Int = 200,
        data: Data = Data(),
        headers: [String: String] = [:],
        errorCode: URLError.Code? = nil
    ) {
        configure(
            stubs: [
                Stub(
                    statusCode: statusCode,
                    data: data,
                    headers: headers,
                    errorCode: errorCode
                )
            ]
        )
    }

    static func configure(stubs: [Stub]) {
        responses.withLock { $0 = stubs }
        recordedRequests.withLock { $0 = [] }
    }

    static func request() -> URLRequest? {
        recordedRequests.withLock { $0.last }
    }

    static func requests() -> [URLRequest] {
        recordedRequests.withLock { $0 }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        var recordedRequest = request
        if recordedRequest.httpBody == nil,
           let bodyStream = recordedRequest.httpBodyStream {
            bodyStream.open()
            defer { bodyStream.close() }

            var body = Data()
            var buffer = [UInt8](repeating: 0, count: 1_024)
            while bodyStream.hasBytesAvailable {
                let count = bodyStream.read(&buffer, maxLength: buffer.count)
                guard count > 0 else { break }
                body.append(buffer, count: count)
            }
            recordedRequest.httpBody = body
        }
        Self.recordedRequests.withLock { $0.append(recordedRequest) }
        let stub = Self.responses.withLock {
            guard !$0.isEmpty else {
                return Stub(statusCode: 500)
            }
            return $0.removeFirst()
        }

        if let errorCode = stub.errorCode {
            client?.urlProtocol(self, didFailWithError: URLError(errorCode))
            return
        }

        guard let url = request.url,
              let response = HTTPURLResponse(
                url: url,
                statusCode: stub.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: stub.headers.merging(
                    ["Content-Type": "application/json"],
                    uniquingKeysWith: { first, _ in first }
                )
              ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
