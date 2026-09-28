import UIKit
import GoogleMaps

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let key = Bundle.main.object(forInfoDictionaryKey: "MapsAPIKey") as? String ?? ""
        if !key.isEmpty && key != "YOUR_API_KEY" {
            GMSServices.provideAPIKey(key)
        }
        return true
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        window = UIWindow(windowScene: windowScene)
        let key = Bundle.main.object(forInfoDictionaryKey: "MapsAPIKey") as? String ?? ""
        if key.isEmpty || key == "YOUR_API_KEY" {
            let controller = UIViewController()
            controller.view.backgroundColor = .systemBackground
            let label = UILabel()
            label.text = "Set MAPS_API_KEY in Config/Local.xcconfig, then build again. See README.md."
            label.numberOfLines = 0
            label.textAlignment = .center
            label.frame = controller.view.bounds.insetBy(dx: 24, dy: 100)
            label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            controller.view.addSubview(label)
            window?.rootViewController = controller
        } else {
            window?.rootViewController = ReproViewController()
        }
        window?.makeKeyAndVisible()
    }
}
