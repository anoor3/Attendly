import Foundation
import CoreLocation

protocol LocationValidating {
    func requestLocationPermission() async throws
    func validate(location: CLLocation, within radius: CLLocationDistance, of classroom: CLLocation) -> Bool
}

final class LocationValidator: NSObject, LocationValidating, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var permissionContinuation: CheckedContinuation<Void, Error>?

    override init() {
        super.init()
        manager.delegate = self
    }

    enum LocationError: Error {
        case denied
    }

    func requestLocationPermission() async throws {
        manager.requestWhenInUseAuthorization()
        try await withCheckedThrowingContinuation { continuation in
            permissionContinuation = continuation
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard let continuation = permissionContinuation else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            continuation.resume()
        case .denied, .restricted:
            continuation.resume(throwing: LocationError.denied)
        default:
            break
        }
        permissionContinuation = nil
    }

    func validate(location: CLLocation, within radius: CLLocationDistance, of classroom: CLLocation) -> Bool {
        classroom.distance(from: location) <= radius
    }
}

protocol QRTokenProviding {
    func generateToken(for session: Session, window: TimeInterval) -> String
}

struct QRTokenProvider: QRTokenProviding {
    func generateToken(for session: Session, window: TimeInterval) -> String {
        let bucket = Int(Date().timeIntervalSince1970 / window)
        return "\(session.id.uuidString)|\(bucket)|\(session.qrSeed)"
    }
}

protocol Exporting {
    func exportCSV(for attendance: [AttendanceRecord]) -> URL?
}

struct ExportService: Exporting {
    func exportCSV(for attendance: [AttendanceRecord]) -> URL? {
        let rows = attendance.map { record in
            "\(record.id),\(record.sessionId),\(record.studentId),\(record.status.rawValue),\(record.timestamp),\(record.locationVerified)"
        }
        let csv = (["recordId,sessionId,studentId,status,timestamp,locationVerified"] + rows).joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("attendance-\(UUID().uuidString).csv")
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
