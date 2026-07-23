import Foundation
import Services
import Synchronization

final class TestAuthenticationClock: AuthenticationClock, Sendable {
    private let value: Mutex<Date>

    init(now: Date) {
        value = Mutex(now)
    }

    var now: Date {
        value.withLock { $0 }
    }

    func advance(to date: Date) {
        value.withLock { $0 = date }
    }
}
