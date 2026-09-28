import UIKit
import GoogleMaps

final class ReproViewController: UIViewController {
    private let status = UILabel()
    private let controls = UISegmentedControl(items: Scenario.allCases.map(\.title))
    private let share = UIButton(type: .system)
    private let start = UIButton(type: .system)
    private var map: GMSMapView?
    private var layer: ReproTileLayer?
    private var timer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        status.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        status.numberOfLines = 3
        share.setTitle("Share log", for: .normal)
        share.addTarget(self, action: #selector(shareLog), for: .touchUpInside)
        share.isEnabled = false
        start.configuration = .filled()
        start.setTitle("Start", for: .normal)
        start.addTarget(self, action: #selector(startScenario), for: .touchUpInside)
        controls.addTarget(self, action: #selector(selectScenario), for: .valueChanged)
        let requested = ProcessInfo.processInfo.arguments.compactMap(Scenario.init(rawValue:)).first ?? .mixed
        controls.selectedSegmentIndex = Scenario.allCases.firstIndex(of: requested)!
        let header = UIStackView(arrangedSubviews: [status, share])
        header.spacing = 8
        [header, controls, start].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; view.addSubview($0) }
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            header.heightAnchor.constraint(equalToConstant: 54),
            share.widthAnchor.constraint(equalToConstant: 76),
            controls.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 6),
            controls.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            controls.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            controls.heightAnchor.constraint(equalToConstant: 32),
            start.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            start.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            start.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            start.heightAnchor.constraint(equalToConstant: 48)
        ])
        selectScenario()
    }

    @objc private func selectScenario() {
        guard layer?.pending ?? 0 == 0 else { return }
        timer?.invalidate()
        layer?.stop()
        layer = nil
        map?.removeFromSuperview()
        map = nil
        share.isEnabled = false
        start.isEnabled = true
        status.text = "SDK \(GMSServices.sdkVersion())\nChoose a case, then tap Start.\nGreen = local · orange = delayed"
    }

    @objc private func startScenario() {
        guard layer?.pending ?? 0 == 0 else { return }
        selectScenario()
        let scenario = Scenario.allCases[controls.selectedSegmentIndex]
        do {
            let log = try EventLog(scenario: scenario)
            let newLayer = try ReproTileLayer(scenario: scenario, log: log)
            let options = GMSMapViewOptions()
            options.camera = GMSCameraPosition(latitude: ReproTileLayer.latitude,
                                              longitude: ReproTileLayer.longitude, zoom: 16)
            let newMap = GMSMapView(options: options)
            newMap.mapType = .none
            newMap.settings.setAllGesturesEnabled(false)
            newMap.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(newMap)
            NSLayoutConstraint.activate([
                newMap.topAnchor.constraint(equalTo: controls.bottomAnchor, constant: 6),
                newMap.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                newMap.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                newMap.bottomAnchor.constraint(equalTo: start.topAnchor, constant: -8)
            ])
            view.layoutIfNeeded()
            log.write("VIEW width=\(newMap.bounds.width) height=\(newMap.bounds.height) scale=\(view.window?.screen.scale ?? 0)")
            map = newMap
            layer = newLayer
            share.isEnabled = true
            newLayer.map = newMap
            refreshStatus()
            timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                self?.refreshStatus()
            }
            // Avoid detaching a layer with uncompleted requests. Relaunch for independent comparisons.
            controls.isEnabled = false
            start.isEnabled = false
        } catch {
            status.text = "Setup failed: \(error.localizedDescription)"
        }
    }

    private func refreshStatus() {
        guard let layer else { return }
        status.text = "SDK \(GMSServices.sdkVersion()) · \(Int(layer.log.elapsed))s\nRequests \(layer.requests) · returned \(layer.deliveries) · pending \(layer.pending)\nGreen = local · orange = delayed"
        controls.isEnabled = layer.pending == 0 && layer.log.elapsed >= 2
        start.isEnabled = controls.isEnabled
    }

    @objc private func shareLog() {
        guard let layer else { return }
        let controller = UIActivityViewController(activityItems: [layer.log.url], applicationActivities: nil)
        controller.popoverPresentationController?.sourceView = share
        present(controller, animated: true)
    }
}
