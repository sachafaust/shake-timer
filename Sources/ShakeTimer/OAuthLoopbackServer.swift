import Foundation
import Network

enum OAuthLoopbackError: LocalizedError {
    case invalidPort
    case listenerFailed
    case missingCode

    var errorDescription: String? {
        switch self {
        case .invalidPort:
            "Could not create the OAuth loopback port."
        case .listenerFailed:
            "Could not start the OAuth loopback server."
        case .missingCode:
            "Google did not return an OAuth code."
        }
    }
}

final class OAuthLoopbackServer: @unchecked Sendable {
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "ShakeTimer.OAuthLoopback")
    private var completion: (@Sendable (Result<String, Error>) -> Void)?

    func start(
        port: UInt16 = 53682,
        completion: @escaping @Sendable (Result<String, Error>) -> Void
    ) throws -> URL {
        guard let nwPort = NWEndpoint.Port(rawValue: port),
              let redirectURL = URL(string: "http://127.0.0.1:\(port)/oauth2redirect") else {
            throw OAuthLoopbackError.invalidPort
        }

        self.completion = completion
        let listener = try NWListener(using: .tcp, on: nwPort)
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
        listener.stateUpdateHandler = { [weak self] state in
            if case .failed = state {
                self?.finish(.failure(OAuthLoopbackError.listenerFailed))
            }
        }
        listener.start(queue: queue)
        self.listener = listener
        return redirectURL
    }

    func stop() {
        listener?.cancel()
        listener = nil
        completion = nil
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, _, _ in
            guard let self else { return }
            let codeResult = self.parseCode(from: data)
            let body = """
            <html><body><h3>ShakeTimer connected.</h3><p>You can close this tab.</p></body></html>
            """
            let response = """
            HTTP/1.1 200 OK\r
            Content-Type: text/html; charset=utf-8\r
            Content-Length: \(body.utf8.count)\r
            Connection: close\r
            \r
            \(body)
            """
            connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
                connection.cancel()
            })
            self.finish(codeResult)
        }
    }

    private func parseCode(from data: Data?) -> Result<String, Error> {
        guard let data,
              let request = String(data: data, encoding: .utf8),
              let firstLine = request.split(separator: "\r\n").first,
              let path = firstLine.split(separator: " ").dropFirst().first,
              let components = URLComponents(string: "http://127.0.0.1\(path)"),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              !code.isEmpty else {
            return .failure(OAuthLoopbackError.missingCode)
        }
        return .success(code)
    }

    private func finish(_ result: Result<String, Error>) {
        let callback = completion
        stop()
        DispatchQueue.main.async {
            callback?(result)
        }
    }
}
