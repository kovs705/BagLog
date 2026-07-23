import Foundation

public struct SystemAuthenticationClock: AuthenticationClock {
    public init() {}

    public var now: Date {
        .now
    }
}
