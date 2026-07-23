import Foundation

public protocol AuthenticationClock: Sendable {
    var now: Date { get }
}
