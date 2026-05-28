import AppKit
import Foundation
import ShakeTimerCore

enum GoogleCalendarError: LocalizedError {
    case missingClientID
    case missingRefreshToken
    case invalidResponse
    case api(String)

    var errorDescription: String? {
        switch self {
        case .missingClientID:
            "Add a Google OAuth client ID in Settings before connecting Calendar."
        case .missingRefreshToken:
            "Google did not return a refresh token. Disconnect and connect again."
        case .invalidResponse:
            "Google returned an invalid response."
        case .api(let message):
            message
        }
    }
}

struct GoogleToken: Codable {
    var accessToken: String
    var refreshToken: String?
    var expiresAt: Date

    var shouldRefresh: Bool {
        Date().addingTimeInterval(60) >= expiresAt
    }
}

@MainActor
final class GoogleCalendarService: ObservableObject {
    @Published private(set) var isConnected = false
    @Published private(set) var status = "Google Calendar disconnected"

    private let keychain = KeychainStore()
    private let tokenAccount = "google-token"
    private let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!
    private let scope = "https://www.googleapis.com/auth/calendar.readonly"
    private let loopbackServer = OAuthLoopbackServer()
    private let decoder: JSONDecoder

    init() {
        decoder = JSONDecoder()
        isConnected = (try? loadToken()) != nil
        status = isConnected ? "Google Calendar connected" : "Google Calendar disconnected"
    }

    func connect(settings: AppSettings, clientSecret: String) async throws {
        guard !settings.googleClientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GoogleCalendarError.missingClientID
        }

        let port: UInt16 = 53682
        let redirectURL = URL(string: "http://127.0.0.1:\(port)/oauth2redirect")!
        let code = try await withCheckedThrowingContinuation { continuation in
            do {
                let authURL = try self.authorizationURL(
                    clientID: settings.googleClientID,
                    redirectURI: redirectURL.absoluteString
                )
                _ = try self.loopbackServer.start(port: port) { result in
                    switch result {
                    case .success(let code):
                        continuation.resume(returning: code)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                NSWorkspace.shared.open(authURL)
            } catch {
                continuation.resume(throwing: error)
            }
        }

        let token = try await exchangeCode(
            code,
            clientID: settings.googleClientID,
            clientSecret: clientSecret,
            redirectURI: redirectURL.absoluteString
        )
        try saveToken(token)
        isConnected = true
        status = "Google Calendar connected"
    }

    func disconnect() {
        try? keychain.delete(account: tokenAccount)
        isConnected = false
        status = "Google Calendar disconnected"
    }

    func fetchUpcomingEvents(settings: AppSettings, clientSecret: String) async throws -> [CalendarEvent] {
        var token = try loadToken()
        if token.shouldRefresh {
            token = try await refreshToken(
                token,
                clientID: settings.googleClientID,
                clientSecret: clientSecret
            )
            try saveToken(token)
        }

        let calendarID = settings.selectedCalendarID.isEmpty ? "primary" : settings.selectedCalendarID
        let encodedCalendarID = calendarID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "primary"
        var components = URLComponents(
            string: "https://www.googleapis.com/calendar/v3/calendars/\(encodedCalendarID)/events"
        )!
        let now = Date()
        components.queryItems = [
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime"),
            URLQueryItem(name: "timeMin", value: Self.isoString(from: now)),
            URLQueryItem(name: "timeMax", value: Self.isoString(from: now.addingTimeInterval(24 * 60 * 60))),
            URLQueryItem(name: "maxResults", value: "20")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        let apiResponse = try decoder.decode(GoogleEventsResponse.self, from: data)
        let events = apiResponse.items.compactMap { $0.calendarEvent(calendarID: calendarID) }
        status = "Fetched \(events.count) upcoming event\(events.count == 1 ? "" : "s")"
        return events
    }

    private func authorizationURL(clientID: String, redirectURI: String) throws -> URL {
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]
        guard let url = components.url else { throw GoogleCalendarError.invalidResponse }
        return url
    }

    private func exchangeCode(
        _ code: String,
        clientID: String,
        clientSecret: String,
        redirectURI: String
    ) async throws -> GoogleToken {
        var fields = [
            "code": code,
            "client_id": clientID,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code"
        ]
        if !clientSecret.isEmpty {
            fields["client_secret"] = clientSecret
        }
        let token = try await postToken(fields)
        guard token.refreshToken != nil else { throw GoogleCalendarError.missingRefreshToken }
        return token
    }

    private func refreshToken(
        _ oldToken: GoogleToken,
        clientID: String,
        clientSecret: String
    ) async throws -> GoogleToken {
        guard let refreshToken = oldToken.refreshToken else { throw GoogleCalendarError.missingRefreshToken }
        var fields = [
            "refresh_token": refreshToken,
            "client_id": clientID,
            "grant_type": "refresh_token"
        ]
        if !clientSecret.isEmpty {
            fields["client_secret"] = clientSecret
        }
        var newToken = try await postToken(fields)
        newToken.refreshToken = newToken.refreshToken ?? refreshToken
        return newToken
    }

    private func postToken(_ fields: [String: String]) async throws -> GoogleToken {
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = fields.formURLEncoded.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        let tokenResponse = try decoder.decode(GoogleTokenResponse.self, from: data)
        return GoogleToken(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
        )
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleCalendarError.invalidResponse
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            let body = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw GoogleCalendarError.api(body)
        }
    }

    private func loadToken() throws -> GoogleToken {
        guard let rawToken = try keychain.load(account: tokenAccount),
              let data = rawToken.data(using: .utf8) else {
            throw GoogleCalendarError.missingRefreshToken
        }
        return try decoder.decode(GoogleToken.self, from: data)
    }

    private func saveToken(_ token: GoogleToken) throws {
        let data = try JSONEncoder().encode(token)
        try keychain.save(String(decoding: data, as: UTF8.self), account: tokenAccount)
    }

    private static func isoString(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}

private struct GoogleTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

private struct GoogleEventsResponse: Decodable {
    let items: [GoogleEvent]
}

private struct GoogleEvent: Decodable {
    struct DateValue: Decodable {
        let dateTime: String?
        let date: String?
    }

    let id: String
    let summary: String?
    let start: DateValue
    let end: DateValue?

    func calendarEvent(calendarID: String) -> CalendarEvent? {
        guard let startDate = Self.parse(start.dateTime) ?? Self.parseDateOnly(start.date) else { return nil }
        return CalendarEvent(
            id: id,
            title: summary?.isEmpty == false ? summary! : "Untitled event",
            startDate: startDate,
            endDate: Self.parse(end?.dateTime) ?? Self.parseDateOnly(end?.date),
            calendarID: calendarID
        )
    }

    private static func parse(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }

    private static func parseDateOnly(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }
}

private extension Dictionary where Key == String, Value == String {
    var formURLEncoded: String {
        map { key, value in
            "\(key.urlFormEncoded)=\(value.urlFormEncoded)"
        }
        .sorted()
        .joined(separator: "&")
    }
}

private extension String {
    var urlFormEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlFormAllowed) ?? self
    }
}

private extension CharacterSet {
    static let urlFormAllowed: CharacterSet = {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: ":#[]@!$&'()*+,;=")
        return allowed
    }()
}
