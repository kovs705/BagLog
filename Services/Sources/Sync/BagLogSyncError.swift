import Foundation

public enum BagLogSyncError: Error, Equatable, Sendable {
    case cancelled
    case configuration
    case cursorExpired
    case forbidden
    case idempotencyConflict(traceID: String?)
    case internalError
    case invalidCursor
    case invalidRequest
    case invalidToken
    case loadoutConflict
    case loadoutNotFound
    case mutationInProgress(retryAfter: TimeInterval?)
    case networkUnavailable
    case profileConflict
    case profileNotFound
    case profileRequired
    case responseTooLarge
    case revisionMismatch
    case revisionRequired
    case serviceUnavailable
    case timedOut
    case unexpectedResponse

    public var stableCode: String {
        switch self {
        case .cancelled: "cancelled"
        case .configuration: "configuration"
        case .cursorExpired: "cursor_expired"
        case .forbidden: "forbidden"
        case .idempotencyConflict: "idempotency_conflict"
        case .internalError: "internal_error"
        case .invalidCursor: "invalid_cursor"
        case .invalidRequest: "invalid_request"
        case .invalidToken: "invalid_token"
        case .loadoutConflict: "loadout_conflict"
        case .loadoutNotFound: "loadout_not_found"
        case .mutationInProgress: "mutation_in_progress"
        case .networkUnavailable: "network_unavailable"
        case .profileConflict: "profile_conflict"
        case .profileNotFound: "profile_not_found"
        case .profileRequired: "profile_required"
        case .responseTooLarge: "response_too_large"
        case .revisionMismatch: "revision_mismatch"
        case .revisionRequired: "revision_required"
        case .serviceUnavailable: "service_unavailable"
        case .timedOut: "timed_out"
        case .unexpectedResponse: "unexpected_response"
        }
    }

    public var isRetryable: Bool {
        switch self {
        case .mutationInProgress, .networkUnavailable, .serviceUnavailable,
             .timedOut, .internalError:
            true
        default:
            false
        }
    }
}

extension BagLogSyncError: CustomStringConvertible {
    public var description: String {
        stableCode
    }
}
