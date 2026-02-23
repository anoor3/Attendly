import Foundation
import SwiftUI
import CoreLocation
import Combine

final class RoleRouterViewModel: ObservableObject {
    @Published var role: UserRole? = nil
}

@MainActor
final class ProfessorDashboardViewModel: ObservableObject {
    @Published var selectedClassId: UUID?
    @Published var qrWindow: TimeInterval = 90
    @Published var lateThresholdMinutes: Int = 5
    @Published var showCreateClassSheet = false

    private let appState: AppState
    private var cancellables = Set<AnyCancellable>()

    init(appState: AppState) {
        self.appState = appState
        self.selectedClassId = appState.classes.first?.id
        appState.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    var profile: ProfessorProfile { appState.professorProfile }
    var classes: [AttendlyClass] { appState.classes }
    var activeClass: AttendlyClass? {
        if let selected = selectedClassId {
            return classes.first(where: { $0.id == selected })
        }
        return classes.first
    }
    var liveSession: Session? {
        guard let activeClass else { return nil }
        return appState.activeSession(for: activeClass)
    }
    var qrToken: String {
        guard let session = liveSession else { return "" }
        return appState.qrToken(for: session)
    }
    var attendanceCount: Int {
        guard let session = liveSession else { return 0 }
        return appState.attendanceCount(for: session)
    }

    func startSession() {
        guard let attendlyClass = activeClass else { return }
        appState.startSession(for: attendlyClass, qrWindow: qrWindow, lateThreshold: lateThresholdMinutes)
    }

    func endSession() {
        guard let attendlyClass = activeClass else { return }
        appState.endSession(for: attendlyClass)
    }

    func createClass(from form: ClassFormInput) {
        appState.createClass(from: form)
        if selectedClassId == nil {
            selectedClassId = appState.classes.first?.id
        }
    }
}

@MainActor
final class StudentHomeViewModel: ObservableObject {
    @Published var isScanning = false
    @Published var confirmation: AttendanceConfirmation?
    @Published var pendingEnrollment: EnrollmentPrompt?

    private let appState: AppState
    private let locationService: LocationServicing
    private var cancellables = Set<AnyCancellable>()

    init(appState: AppState, locationService: LocationServicing = LocationValidator()) {
        self.appState = appState
        self.locationService = locationService
        appState.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    var profile: StudentProfile { appState.studentProfile }
    var attendanceProgress: Double { profile.summary.attendancePercentage / 100 }
    var classes: [AttendlyClass] { appState.classes }
    var attendanceHistory: [AttendanceRecord] {
        appState.attendanceRecords.sorted { $0.timestamp > $1.timestamp }
    }
    func className(for record: AttendanceRecord) -> String {
        guard let session = appState.session(by: record.sessionId),
              let attendlyClass = appState.classForSession(session) else { return "Class" }
        return attendlyClass.name
    }

    func status(for record: AttendanceRecord) -> StatusPill.Status {
        switch record.status {
        case .onTime:
            return .present
        case .late:
            return .late
        case .absent:
            return .absent
        }
    }

    func handleScannedCode(_ code: String) {
        guard let payload = appState.decodeToken(code) else {
            confirmation = AttendanceConfirmation(message: message(for: .invalid), result: .invalid)
            isScanning = false
            return
        }

        if appState.isStudentEnrolled(in: payload.classId) {
            isScanning = false
            Task { await verify(token: code) }
        } else {
            pendingEnrollment = EnrollmentPrompt(token: code, payload: payload)
            isScanning = false
        }
    }

    func confirmEnrollment(for prompt: EnrollmentPrompt) {
        pendingEnrollment = nil
        appState.enrollStudent(in: prompt.payload.classId)
        Task { await verify(token: prompt.token) }
    }

    func cancelEnrollmentPrompt() {
        pendingEnrollment = nil
    }

    private func simulateLocation() -> CLLocation {
        if let coordinate = classes.first?.coordinate {
            return CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        }
        return CLLocation(latitude: 0, longitude: 0)
    }

    @MainActor
    private func verify(token: String) async {
        do {
            #if targetEnvironment(simulator)
            let location = simulateLocation()
            let result = appState.verifyScan(token: token, location: location)
            confirmation = AttendanceConfirmation(message: message(for: result), result: result)
            #else
            try await locationService.requestAuthorization()
            let location = try await locationService.requestCurrentLocation()
            let result = appState.verifyScan(token: token, location: location)
            confirmation = AttendanceConfirmation(message: message(for: result), result: result)
            #endif
        } catch {
            confirmation = AttendanceConfirmation(message: "Location required to verify check-in", result: .outsideGeofence)
        }
    }

    struct EnrollmentPrompt: Identifiable {
        let id = UUID()
        let token: String
        let payload: QRPayload
    }

    private func message(for result: AttendanceResult) -> String {
        switch result {
        case .success:
            return "Checked in successfully"
        case .expired:
            return "QR expired. Ask professor to refresh."
        case .locked:
            return "Session locked by professor."
        case .outsideGeofence:
            return "Move closer to the classroom."
        case .invalid:
            return "Invalid QR code."
        }
    }
}
