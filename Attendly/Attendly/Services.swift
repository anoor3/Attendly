import Foundation
import CoreLocation

protocol LocationServicing {
    func requestAuthorization() async throws
    func requestCurrentLocation() async throws -> CLLocation
}

final class LocationValidator: NSObject, LocationServicing, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var permissionContinuation: CheckedContinuation<Void, Error>?
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    enum LocationError: Error {
        case denied
        case unavailable
    }

    func requestAuthorization() async throws {
        manager.requestWhenInUseAuthorization()
        try await withCheckedThrowingContinuation { continuation in
            permissionContinuation = continuation
        }
    }

    func requestCurrentLocation() async throws -> CLLocation {
        manager.requestLocation()
        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
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

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        locationContinuation?.resume(returning: location)
        locationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationContinuation?.resume(throwing: error)
        locationContinuation = nil
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
