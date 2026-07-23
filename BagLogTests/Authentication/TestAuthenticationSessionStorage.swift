import Services

actor TestAuthenticationSessionStorage: AuthenticationSessionStoring {
    private var session: AuthenticationSession?
    private let loadError: Error?
    private let saveError: Error?
    private let clearError: Error?
    private var saveFailuresRemaining: Int
    private var saved: [AuthenticationSession] = []
    private var clearCallCount = 0

    init(
        session: AuthenticationSession? = nil,
        loadError: Error? = nil,
        saveError: Error? = nil,
        clearError: Error? = nil,
        saveFailuresRemaining: Int = 0
    ) {
        self.session = session
        self.loadError = loadError
        self.saveError = saveError
        self.clearError = clearError
        self.saveFailuresRemaining = saveFailuresRemaining
    }

    func load() throws -> AuthenticationSession? {
        if let loadError {
            throw loadError
        }
        return session
    }

    func save(_ session: AuthenticationSession) throws {
        if saveFailuresRemaining > 0 {
            saveFailuresRemaining -= 1
            throw AuthenticationError.secureStorage
        }
        if let saveError {
            throw saveError
        }
        self.session = session
        saved.append(session)
    }

    func clear() throws {
        if let clearError {
            throw clearError
        }
        session = nil
        clearCallCount += 1
    }

    func currentSession() -> AuthenticationSession? {
        session
    }

    func savedSessions() -> [AuthenticationSession] {
        saved
    }

    func clearCount() -> Int {
        clearCallCount
    }
}
