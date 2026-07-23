#if DEBUG
import Services

actor AuthenticationUITestSessionStorage: AuthenticationSessionStoring {
    private var session: AuthenticationSession?

    init(session: AuthenticationSession?) {
        self.session = session
    }

    func load() -> AuthenticationSession? {
        session
    }

    func save(_ session: AuthenticationSession) {
        self.session = session
    }

    func clear() {
        session = nil
    }
}
#endif
