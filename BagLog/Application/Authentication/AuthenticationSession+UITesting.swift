#if DEBUG
import Foundation
import Services

extension AuthenticationSession {
    static var uiTestSession: AuthenticationSession {
        AuthenticationSession(
            accessToken: "ui-test-access-token",
            accessExpiresAt: .now.addingTimeInterval(3_600),
            refreshToken: "ui-test-refresh-token",
            refreshExpiresAt: .now.addingTimeInterval(86_400),
            tokenType: "Bearer"
        )
    }
}
#endif
