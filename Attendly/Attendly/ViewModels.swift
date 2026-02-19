import Foundation
import SwiftUI

final class RoleRouterViewModel: ObservableObject {
    @Published var role: UserRole? = nil
}

@MainActor
final class ProfessorDashboardViewModel: ObservableObject {
    @Published var profile: ProfessorProfile
    @Published var liveSession: Session?
    @Published var attendanceCount: Int = 0
    @Published var qrWindow: TimeInterval = 90

    private let qrProvider: QRTokenProviding

    init(profile: ProfessorProfile, qrProvider: QRTokenProviding = QRTokenProvider()) {
        self.profile = profile
        self.qrProvider = qrProvider
    }

    var activeClass: AttendlyClass? { profile.classes.first }

    var qrToken: String {
        guard let session = liveSession else { return "" }
        return qrProvider.generateToken(for: session, window: qrWindow)
    }

    func startSession(for attendlyClass: AttendlyClass) {
        liveSession = Session(
            classId: attendlyClass.id,
            startTime: .now,
            qrSeed: UUID().uuidString,
            lateThresholdMinutes: 5,
            isLocked: false
        )
        attendanceCount = 0
    }

    func endSession() {
        liveSession?.endTime = .now
        liveSession?.isLocked = true
    }

    func incrementAttendance() {
        guard liveSession != nil else { return }
        attendanceCount += 1
    }
}

@MainActor
final class StudentHomeViewModel: ObservableObject {
    @Published var profile: StudentProfile
    @Published var isScanning = false
    @Published var confirmationMessage: String?

    init(profile: StudentProfile) {
        self.profile = profile
    }

    var attendanceProgress: Double {
        profile.summary.attendancePercentage / 100
    }

    func confirmAttendance(success: Bool) {
        confirmationMessage = success ? "Checked in successfully" : "Unable to verify location"
        if success {
            profile.summary.onTimeCount += 1
        }
    }
}
