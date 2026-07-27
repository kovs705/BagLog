import Foundation

public struct LoadoutSyncEngineDependencies: Sendable {
    public let now: @Sendable () -> Date
    public let makeUUID: @Sendable () -> UUID
    public let jitter: @Sendable (ClosedRange<TimeInterval>) -> TimeInterval

    public init(
        now: @escaping @Sendable () -> Date,
        makeUUID: @escaping @Sendable () -> UUID,
        jitter: @escaping @Sendable (ClosedRange<TimeInterval>) -> TimeInterval
    ) {
        self.now = now
        self.makeUUID = makeUUID
        self.jitter = jitter
    }

    public static let live = LoadoutSyncEngineDependencies(
        now: { .now },
        makeUUID: { UUID() },
        jitter: { range in Double.random(in: range) }
    )
}
