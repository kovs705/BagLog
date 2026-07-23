import Services

struct AuthenticationDependencies: Sendable {
    let identityProvider: any GoogleIdentityProviding
    let api: any AuthenticationAPIProviding
    let sessionStorage: any AuthenticationSessionStoring
    let clock: any AuthenticationClock
}
