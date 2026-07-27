import Services

struct AuthenticationDependencies: Sendable {
    let identityProvider: any GoogleIdentityProviding
    let sessionController: any BagLogSessionControlling
}
