import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let w = UIWindow(windowScene: windowScene)
        w.rootViewController = MainViewController()
        w.makeKeyAndVisible()
        window = w

        // Handle URLs passed at launch (e.g. via Files app)
        if let ctx = connectionOptions.urlContexts.first {
            handleURL(ctx.url)
        }
    }

    func scene(_ scene: UIScene, openURLContexts urlContexts: Set<UIOpenURLContext>) {
        if let ctx = urlContexts.first {
            handleURL(ctx.url)
        }
    }

    // MARK: - Private

    private func handleURL(_ url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        Task { @MainActor in
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            await IntentHandler.shared.handle(url: url, view: nil)
        }
    }
}
