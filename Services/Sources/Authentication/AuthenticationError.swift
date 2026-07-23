import Foundation

public enum AuthenticationError: Error, Equatable, Sendable {
    case cancelled
    case configuration
    case invalidRequest
    case missingIdentityToken
    case networkUnavailable
    case providerUnavailable
    case rateLimited
    case rejected
    case responseTooLarge
    case secureStorage
    case serviceUnavailable
    case timedOut
    case unexpectedResponse

    public var userMessage: String {
        switch self {
        case .cancelled:
            ""
        case .configuration:
            "Google sign-in isn’t configured for this build."
        case .invalidRequest, .missingIdentityToken:
            "Google sign-in couldn’t be completed. Please try again."
        case .networkUnavailable:
            "You appear to be offline. Check your connection and try again."
        case .providerUnavailable:
            "Google sign-in is temporarily unavailable. Please try again."
        case .rateLimited:
            "Too many attempts were made. Please wait a moment and try again."
        case .rejected:
            "Your session is no longer valid. Please sign in again."
        case .responseTooLarge, .unexpectedResponse:
            "BagLog received an unexpected response. Please try again."
        case .secureStorage:
            "BagLog couldn’t securely save your session. Please try again."
        case .serviceUnavailable:
            "BagLog’s sign-in service is temporarily unavailable. Please try again."
        case .timedOut:
            "The request timed out. Please try again."
        }
    }
}

extension AuthenticationError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .cancelled: "cancelled"
        case .configuration: "configuration"
        case .invalidRequest: "invalidRequest"
        case .missingIdentityToken: "missingIdentityToken"
        case .networkUnavailable: "networkUnavailable"
        case .providerUnavailable: "providerUnavailable"
        case .rateLimited: "rateLimited"
        case .rejected: "rejected"
        case .responseTooLarge: "responseTooLarge"
        case .secureStorage: "secureStorage"
        case .serviceUnavailable: "serviceUnavailable"
        case .timedOut: "timedOut"
        case .unexpectedResponse: "unexpectedResponse"
        }
    }
}
