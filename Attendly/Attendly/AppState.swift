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
    private let defaults: UserDefaults

    private enum StorageKey {
        static let classes = "attendly.classes"
        static let attendanceRecords = "attendly.attendanceRecords"
        static let studentProfile = "attendly.studentProfile"
    }

    init(
        classes initialClasses: [AttendlyClass] = [SampleData.exampleClass],
        professorProfile: ProfessorProfile = SampleData.professor,
        studentProfile initialStudentProfile: StudentProfile = SampleData.student,
        qrProvider: QRTokenProviding = QRTokenProvider(),
        userDefaults: UserDefaults = .standard
    ) {
        self.defaults = userDefaults
        self.qrProvider = qrProvider
        self.classes = AppState.loadValue(from: userDefaults, key: StorageKey.classes) ?? initialClasses
        self.sessions = [:]
        self.attendanceRecords = AppState.loadValue(from: userDefaults, key: StorageKey.attendanceRecords) ?? []
        self.professorProfile = professorProfile
        self.studentProfile = AppState.loadValue(from: userDefaults, key: StorageKey.studentProfile) ?? initialStudentProfile
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
        persistClasses()
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
            return .alreadyCheckedIn
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
        persistAttendanceRecords()
        persistStudentProfile()
        return .success
    }

    func cacheClass(from payload: QRPayload) {
        _ = upsertClass(from: payload)
    }

    @discardableResult
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
        persistClasses()
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
        if studentProfile.enrolledClassIds.insert(classId).inserted {
            persistStudentProfile()
        }
    }

    private func persistClasses() {
        saveValue(classes, forKey: StorageKey.classes)
    }

    private func persistAttendanceRecords() {
        saveValue(attendanceRecords, forKey: StorageKey.attendanceRecords)
    }

    private func persistStudentProfile() {
        saveValue(studentProfile, forKey: StorageKey.studentProfile)
    }

    private func saveValue<T: Encodable>(_ value: T, forKey key: String) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(value) {
            defaults.set(data, forKey: key)
        }
    }

    private static func loadValue<T: Decodable>(from defaults: UserDefaults, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
