import Foundation

public struct AuthenticationSession: Codable, Equatable, Sendable {
    public let accessToken: String
    public let accessExpiresAt: Date
    public let refreshToken: String
    public let refreshExpiresAt: Date
    public let tokenType: String

    public init(
        accessToken: String,
        accessExpiresAt: Date,
        refreshToken: String,
        refreshExpiresAt: Date,
        tokenType: String
    ) {
        self.accessToken = accessToken
        self.accessExpiresAt = accessExpiresAt
        self.refreshToken = refreshToken
        self.refreshExpiresAt = refreshExpiresAt
        self.tokenType = tokenType
    }

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case accessExpiresAt = "access_expires_at"
        case refreshToken = "refresh_token"
        case refreshExpiresAt = "refresh_expires_at"
        case tokenType = "token_type"
    }
}
