import Foundation
import CoreLocation

enum UserRole: String, CaseIterable, Identifiable {
    case professor
    case student

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .professor: return "Professor"
        case .student: return "Student"
        }
    }
}

struct AttendlyClass: Identifiable, Hashable {
    let id: UUID
    var name: String
    var section: String
    var semester: String
    var room: String
    var meetingDays: [String]
    var geofenceRadius: CLLocationDistance
    var riskLevel: Double

    init(
        id: UUID = UUID(),
        name: String,
        section: String,
        semester: String,
        room: String,
        meetingDays: [String],
        geofenceRadius: CLLocationDistance = 30,
        riskLevel: Double = 0
    ) {
        self.id = id
        self.name = name
        self.section = section
        self.semester = semester
        self.room = room
        self.meetingDays = meetingDays
        self.geofenceRadius = geofenceRadius
        self.riskLevel = riskLevel
    }
}

struct Session: Identifiable, Hashable {
    let id: UUID
    var classId: UUID
    var startTime: Date
    var endTime: Date?
    var qrSeed: String
    var lateThresholdMinutes: Int
    var isLocked: Bool

    init(
        id: UUID = UUID(),
        classId: UUID,
        startTime: Date,
        endTime: Date? = nil,
        qrSeed: String,
        lateThresholdMinutes: Int = 5,
        isLocked: Bool = false
    ) {
        self.id = id
        self.classId = classId
        self.startTime = startTime
        self.endTime = endTime
        self.qrSeed = qrSeed
        self.lateThresholdMinutes = lateThresholdMinutes
        self.isLocked = isLocked
    }
}

enum AttendanceStatus: String {
    case onTime
    case late
    case absent
}

struct AttendanceRecord: Identifiable, Hashable {
    let id: UUID
    var sessionId: UUID
    var studentId: UUID
    var status: AttendanceStatus
    var timestamp: Date
    var locationVerified: Bool

    init(
        id: UUID = UUID(),
        sessionId: UUID,
        studentId: UUID,
        status: AttendanceStatus,
        timestamp: Date = .now,
        locationVerified: Bool
    ) {
        self.id = id
        self.sessionId = sessionId
        self.studentId = studentId
        self.status = status
        self.timestamp = timestamp
        self.locationVerified = locationVerified
    }
}

struct AttendanceSummary {
    var onTimeCount: Int
    var lateCount: Int
    var absentCount: Int

    var attendancePercentage: Double {
        let total = Double(onTimeCount + lateCount + absentCount)
        guard total > 0 else { return 100 }
        return Double(onTimeCount) / total * 100
    }
}

struct StudentProfile: Identifiable {
    let id: UUID
    var name: String
    var deviceHash: String?
    var classes: [AttendlyClass]
    var summary: AttendanceSummary
}

struct ProfessorProfile: Identifiable {
    let id: UUID
    var name: String
    var classes: [AttendlyClass]
}

struct SampleData {
    static let exampleClass = AttendlyClass(
        name: "Intro to Design Systems",
        section: "A",
        semester: "Spring 2026",
        room: "Fine Arts 201",
        meetingDays: ["Mon", "Wed"],
        geofenceRadius: 30,
        riskLevel: 0.12
    )

    static let professor = ProfessorProfile(
        id: UUID(),
        name: "Dr. Celeste Wong",
        classes: [exampleClass]
    )

    static let student = StudentProfile(
        id: UUID(),
        name: "Aiden Cross",
        classes: [exampleClass],
        summary: .init(onTimeCount: 42, lateCount: 3, absentCount: 2)
    )
}
