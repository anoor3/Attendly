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
        guard let attendlyClass = classes.first(where: { $0.id == session.classId }) else { return "" }
        return qrProvider.generateToken(for: session, attendlyClass: attendlyClass)
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
        guard let payload = decodeToken(token) else { return .invalid }

        let nowBucket = Int(Date().timeIntervalSince1970 / payload.qrWindow)
        guard abs(nowBucket - payload.bucket) <= 1 else { return .expired }

        guard let location else { return .outsideGeofence }
        let classLocation = CLLocation(latitude: payload.latitude, longitude: payload.longitude)
        guard classLocation.distance(from: location) <= payload.geofenceRadius else { return .outsideGeofence }

        let attendlyClass = upsertClass(from: payload)
        let session = upsertSession(from: payload, classId: attendlyClass.id)
        enrollStudent(in: attendlyClass.id)

        if session.isLocked { return .locked }
        if session.endTime != nil { return .expired }

        if attendanceRecords.contains(where: { $0.sessionId == session.id && $0.studentId == studentProfile.id }) {
            return .success
        }

        let elapsed = Date().timeIntervalSince(Date(timeIntervalSince1970: payload.sessionStartTime))
        let status: AttendanceStatus = elapsed > Double(payload.lateThresholdMinutes * 60) ? .late : .onTime
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

    private func upsertClass(from payload: QRPayload) -> AttendlyClass {
        let newClass = AttendlyClass(
            id: payload.classId,
            name: payload.className,
            section: payload.section,
            semester: payload.semester,
            room: payload.room,
            meetingDays: payload.meetingDays,
            geofenceRadius: payload.geofenceRadius,
            coordinate: CLLocationCoordinate2D(latitude: payload.latitude, longitude: payload.longitude)
        )
        if let index = classes.firstIndex(where: { $0.id == newClass.id }) {
            classes[index] = newClass
        } else {
            classes.append(newClass)
        }
        return newClass
    }

    private func upsertSession(from payload: QRPayload, classId: UUID) -> Session {
        if let existing = sessions[payload.sessionId] {
            return existing
        }
        let session = Session(
            id: payload.sessionId,
            classId: classId,
            startTime: Date(timeIntervalSince1970: payload.sessionStartTime),
            qrSeed: payload.qrSeed,
            lateThresholdMinutes: payload.lateThresholdMinutes,
            isLocked: false,
            qrWindow: payload.qrWindow
        )
        sessions[session.id] = session
        return session
    }

    func decodeToken(_ token: String) -> QRPayload? {
        guard let data = Data(base64Encoded: token) else { return nil }
        return try? JSONDecoder().decode(QRPayload.self, from: data)
    }

    func isStudentEnrolled(in classId: UUID) -> Bool {
        studentProfile.enrolledClassIds.contains(classId)
    }

    func enrollStudent(in classId: UUID) {
        studentProfile.enrolledClassIds.insert(classId)
    }
}
