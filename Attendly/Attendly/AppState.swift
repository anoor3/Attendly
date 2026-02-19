import Foundation
import CoreLocation

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var classes: [AttendlyClass]
    @Published private(set) var sessions: [UUID: Session]
    @Published private(set) var attendanceRecords: [AttendanceRecord]
    @Published var professorProfile: ProfessorProfile
    @Published var studentProfile: StudentProfile

    private let qrProvider: QRTokenProviding

    init(
        classes: [AttendlyClass] = [SampleData.exampleClass],
        professorProfile: ProfessorProfile = SampleData.professor,
        studentProfile: StudentProfile = SampleData.student,
        qrProvider: QRTokenProviding = QRTokenProvider()
    ) {
        self.classes = classes
        self.sessions = [:]
        self.attendanceRecords = []
        self.professorProfile = professorProfile
        self.studentProfile = studentProfile
        self.qrProvider = qrProvider
    }

    // MARK: - Class management

    func createClass(from form: ClassFormInput) {
        let newClass = AttendlyClass(
            name: form.name,
            section: form.section,
            semester: form.semester,
            room: form.room,
            meetingDays: form.meetingDays,
            geofenceRadius: form.geofenceRadius,
            coordinate: form.coordinate
        )
        classes.append(newClass)
    }

    // MARK: - Session lifecycle

    func startSession(for attendlyClass: AttendlyClass, qrWindow: TimeInterval, lateThreshold: Int) -> Session {
        let session = Session(
            classId: attendlyClass.id,
            startTime: .now,
            qrSeed: UUID().uuidString,
            lateThresholdMinutes: lateThreshold,
            isLocked: false,
            qrWindow: qrWindow
        )
        sessions[session.id] = session
        return session
    }

    func endSession(for attendlyClass: AttendlyClass) {
        guard var session = activeSession(for: attendlyClass) else { return }
        session.endTime = .now
        session.isLocked = true
        sessions[session.id] = session
    }

    func activeSession(for attendlyClass: AttendlyClass) -> Session? {
        sessions.values.first(where: { $0.classId == attendlyClass.id && $0.endTime == nil })
    }

    func qrToken(for session: Session) -> String {
        qrProvider.generateToken(for: session, window: session.qrWindow)
    }

    func attendanceCount(for session: Session) -> Int {
        attendanceRecords.filter { $0.sessionId == session.id }.count
    }

    func session(by id: UUID) -> Session? {
        sessions[id]
    }

    func classForSession(_ session: Session) -> AttendlyClass? {
        classes.first(where: { $0.id == session.classId })
    }

    // MARK: - Attendance scanning

    func verifyScan(token: String, location: CLLocation?) -> AttendanceResult {
        let components = token.split(separator: "|")
        guard components.count >= 3 else { return .invalid }
        guard let sessionId = UUID(uuidString: String(components[0])) else { return .invalid }
        guard let bucket = Int(components[1]) else { return .invalid }

        guard let session = sessions.values.first(where: { $0.id == sessionId }) else { return .invalid }
        guard !session.isLocked else { return .locked }
        guard session.endTime == nil else { return .expired }

        let nowBucket = Int(Date().timeIntervalSince1970 / session.qrWindow)
        guard abs(nowBucket - bucket) <= 1 else { return .expired }

        guard let attendlyClass = classes.first(where: { $0.id == session.classId }) else { return .invalid }

        guard let location else { return .outsideGeofence }
        let classLocation = CLLocation(latitude: attendlyClass.coordinate.latitude, longitude: attendlyClass.coordinate.longitude)
        guard classLocation.distance(from: location) <= attendlyClass.geofenceRadius else { return .outsideGeofence }

        let elapsed = Date().timeIntervalSince(session.startTime)
        let status: AttendanceStatus = elapsed > Double(session.lateThresholdMinutes * 60) ? .late : .onTime
        let record = AttendanceRecord(
            sessionId: session.id,
            studentId: studentProfile.id,
            status: status,
            locationVerified: true
        )
        attendanceRecords.append(record)
        switch status {
        case .onTime:
            studentProfile.summary.onTimeCount += 1
        case .late:
            studentProfile.summary.lateCount += 1
        case .absent:
            studentProfile.summary.absentCount += 1
        }
        return .success
    }
}
