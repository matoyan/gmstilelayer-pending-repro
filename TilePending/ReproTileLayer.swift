import UIKit
import GoogleMaps

enum Scenario: String, CaseIterable {
    case mixed, baseline, immediate

    var title: String {
        switch self {
        case .mixed: return "Mixed · 45s"
        case .baseline: return "All local"
        case .immediate: return "Mixed · 0s"
        }
    }
}

final class EventLog {
    let start = ProcessInfo.processInfo.systemUptime
    let url: URL
    private let file: FileHandle
    var elapsed: Double { ProcessInfo.processInfo.systemUptime - start }

    init(scenario: Scenario) throws {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        url = documents.appendingPathComponent("\(scenario.rawValue)-\(UUID().uuidString).log")
        FileManager.default.createFile(atPath: url.path, contents: nil)
        file = try FileHandle(forWritingTo: url)
        write("START scenario=\(scenario.rawValue) sdk=\(GMSServices.sdkVersion()) ios=\(UIDevice.current.systemVersion)")
    }

    func write(_ message: String) {
        // GMSTileLayer calls and our delayed completions run on the main thread.
        let line = String(format: "%.3f ", elapsed) + message + "\n"
        file.write(Data(line.utf8))
        print(line, terminator: "")
    }

    deinit { try? file.close() }
}

/// A standalone SDK subclass: no application tile loader, HTTP client, or server.
final class ReproTileLayer: GMSTileLayer {
    static let latitude = 36.72
    static let longitude = 138.5
    let log: EventLog
    let scenario: Scenario
    private let directory: URL
    private let orange: UIImage
    private var delayedCache: [String: UIImage] = [:]
    private var scheduled: [DispatchWorkItem] = []
    private(set) var requests = 0
    private(set) var deliveries = 0
    private(set) var pending = 0

    init(scenario: Scenario, log: EventLog) throws {
        self.scenario = scenario
        self.log = log
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        orange = Self.image(color: .systemOrange, text: "DELAYED")
        super.init()
        tileSize = 256
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let green = Self.image(color: .systemGreen, text: "LOCAL z16").pngData()!
        let n = pow(2.0, 16.0)
        let latitudeRadians = Self.latitude * .pi / 180
        let centerX = Int((Self.longitude + 180) / 360 * n)
        let centerY = Int((1 - logLatitude(latitudeRadians) / .pi) / 2 * n)
        for x in (centerX - 10)...(centerX + 10) {
            for y in (centerY - 10)...(centerY + 10) {
                if scenario == .baseline || (x + y).isMultiple(of: 2) {
                    try green.write(to: directory.appendingPathComponent("\(x)-\(y).png"))
                }
            }
        }
        log.write("READY tileSize=256 sourceZoom=16 cameraZoom=16")
    }

    private func logLatitude(_ r: Double) -> Double { Foundation.log(tan(r) + 1 / cos(r)) }

    override func requestTileFor(x: UInt, y: UInt, zoom: UInt, receiver: GMSTileReceiver) {
        requests += 1
        // Keep the original parent-tile geometry. A z18 request uses a z16 parent.
        let parentZoom = min(zoom, 16)
        let divisor = UInt(1) << (zoom - parentZoom)
        let px = x / divisor, py = y / divisor
        let parent = "\(px)-\(py)"
        let saved = parentZoom == 16 ? UIImage(contentsOfFile:
            directory.appendingPathComponent("\(parent).png").path) : nil
        let source = saved != nil ? "local" : (delayedCache[parent] != nil ? "cache" : "delayed")
        let tag = "id=\(requests) z=\(zoom) x=\(x) y=\(y) parent=\(parentZoom)/\(px)/\(py) source=\(source)"
        log.write("REQUEST \(tag)")

        func deliver(_ image: UIImage) {
            let side = CGFloat(image.cgImage!.width) / CGFloat(divisor)
            let rectangle = CGRect(x: CGFloat(x % divisor) * side,
                                   y: CGFloat(y % divisor) * side, width: side, height: side)
            let cropped = image.cgImage!.cropping(to: rectangle)!
            deliveries += 1
            log.write("DELIVER \(tag) pending=\(pending)")
            receiver.receiveTileWith(x: x, y: y, zoom: zoom, image: UIImage(cgImage: cropped))
        }

        if let image = saved ?? delayedCache[parent] {
            deliver(image)
        } else if scenario == .immediate {
            delayedCache[parent] = orange
            deliver(orange)
        } else {
            pending += 1
            log.write("WAIT_BEGIN \(tag) pending=\(pending)")
            // Do not block the main thread or use an app-owned concurrency limit.
            // Each SDK request gets its own completion, including shared parents.
            let work = DispatchWorkItem { [self] in
                pending -= 1
                log.write("WAIT_END \(tag) pending=\(pending)")
                delayedCache[parent] = orange
                deliver(orange)
            }
            scheduled.append(work)
            DispatchQueue.main.asyncAfter(deadline: .now() + 45, execute: work)
        }
    }

    func stop() {
        map = nil
        scheduled.forEach { $0.cancel() }
        scheduled.removeAll()
        try? FileManager.default.removeItem(at: directory)
    }

    private static func image(color: UIColor, text: String) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 256, height: 256), format: format).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 256, height: 256))
            UIColor.black.setStroke()
            context.cgContext.setLineWidth(2)
            context.cgContext.stroke(CGRect(x: 2, y: 2, width: 252, height: 252))
            (text as NSString).draw(at: CGPoint(x: 8, y: 110), withAttributes: [
                .font: UIFont.boldSystemFont(ofSize: 22), .foregroundColor: UIColor.black
            ])
        }
    }
}
