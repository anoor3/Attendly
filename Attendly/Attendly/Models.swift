import Foundation
import CoreLocation

extension CLLocationCoordinate2D: Hashable, Codable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(latitude)
        hasher.combine(longitude)
    }

    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let latitude = try container.decode(CLLocationDegrees.self, forKey: .latitude)
        let longitude = try container.decode(CLLocationDegrees.self, forKey: .longitude)
        self.init(latitude: latitude, longitude: longitude)
    }

    private enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
    }
}

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

struct AttendlyClass: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var section: String
    var semester: String
    var room: String
    var meetingDays: [String]
    var geofenceRadius: CLLocationDistance
    var riskLevel: Double
    var coordinate: CLLocationCoordinate2D

    init(
        id: UUID = UUID(),
        name: String,
        section: String,
        semester: String,
        room: String,
        meetingDays: [String],
        geofenceRadius: CLLocationDistance = 30,
        riskLevel: Double = 0,
        coordinate: CLLocationCoordinate2D = .init(latitude: 37.4275, longitude: -122.1697)
    ) {
        self.id = id
        self.name = name
        self.section = section
        self.semester = semester
        self.room = room
        self.meetingDays = meetingDays
        self.geofenceRadius = geofenceRadius
        self.riskLevel = riskLevel
        self.coordinate = coordinate
    }
}

struct Session: Identifiable, Hashable, Codable {
    let id: UUID
    var classId: UUID
    var startTime: Date
    var endTime: Date?
    var qrSeed: String
    var lateThresholdMinutes: Int
    var isLocked: Bool
    var qrWindow: TimeInterval

    init(
        id: UUID = UUID(),
        classId: UUID,
        startTime: Date,
        endTime: Date? = nil,
        qrSeed: String,
        lateThresholdMinutes: Int = 5,
        isLocked: Bool = false,
        qrWindow: TimeInterval = 90
    ) {
        self.id = id
        self.classId = classId
        self.startTime = startTime
        self.endTime = endTime
        self.qrSeed = qrSeed
        self.lateThresholdMinutes = lateThresholdMinutes
        self.isLocked = isLocked
        self.qrWindow = qrWindow
    }
}

enum AttendanceStatus: String, Codable {
    case onTime
    case late
    case absent
}

struct AttendanceRecord: Identifiable, Hashable, Codable {
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

struct AttendanceSummary: Codable {
    var onTimeCount: Int
    var lateCount: Int
    var absentCount: Int

    var attendancePercentage: Double {
        let total = Double(onTimeCount + lateCount + absentCount)
        guard total > 0 else { return 100 }
        return Double(onTimeCount) / total * 100
    }
}

struct AttendanceConfirmation: Identifiable {
    let id = UUID()
    let message: String
    let result: AttendanceResult
}

struct StudentProfile: Identifiable, Codable {
    let id: UUID
    var name: String
    var deviceHash: String?
    var summary: AttendanceSummary
    var enrolledClassIds: Set<UUID> = []
}

struct ProfessorProfile: Identifiable, Codable {
    let id: UUID
    var name: String
}

struct ClassFormInput {
    var name: String = ""
    var section: String = ""
    var semester: String = ""
    var room: String = ""
    var meetingDays: [String] = []
    var geofenceRadius: CLLocationDistance = 30
    var coordinate: CLLocationCoordinate2D = .init(latitude: 37.4275, longitude: -122.1697)
}

enum AttendanceResult {
    case success
    case alreadyCheckedIn
    case expired
    case locked
    case outsideGeofence
    case invalid
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
        name: "Dr. Celeste Wong"
    )

    static let student = StudentProfile(
        id: UUID(),
        name: "Aiden Cross",
        summary: .init(onTimeCount: 42, lateCount: 3, absentCount: 2),
        enrolledClassIds: [exampleClass.id]
    )
}
