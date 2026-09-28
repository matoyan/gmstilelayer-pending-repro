import UIKit
import GoogleMaps

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
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
            GMSServices.provideAPIKey(key)
            window?.rootViewController = ReproViewController()
        }
        window?.makeKeyAndVisible()
        return true
    }
}
