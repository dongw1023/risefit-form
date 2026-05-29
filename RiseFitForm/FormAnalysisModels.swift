import Foundation

enum Exercise: String, CaseIterable, Identifiable {
    case deadlift
    case squat

    var id: String { rawValue }

    var title: String {
        switch self {
        case .deadlift: return "Deadlift"
        case .squat: return "Squat"
        }
    }
}

enum FormAnalysisStatus: String, Codable {
    case queued
    case processing
    case completed
    case failed
}

struct FormAnalysis: Identifiable, Decodable {
    let id: UUID
    let exercise: String
    let status: FormAnalysisStatus
    let analysedVideoURL: String?
    let report: FormAnalysisReport?
    let error: String?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case exercise
        case status
        case analysedVideoURL = "analysed_video_url"
        case report
        case error
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct FormAnalysisReport: Decodable {
    let exercise: String?
    let formGrade: String?
    let formScore: Double?
    let detectedEvents: [DetectedFormEvent]?
    let viewHealth: Double?
    let totalDuration: Double?

    enum CodingKeys: String, CodingKey {
        case exercise
        case formGrade = "form_grade"
        case formScore = "form_score"
        case detectedEvents = "detected_events"
        case viewHealth = "view_health"
        case totalDuration = "total_duration"
    }
}

struct DetectedFormEvent: Decodable, Identifiable {
    let id = UUID()
    let error: String
    let startTime: Double?
    let endTime: Double?
    let durationSeconds: Double?
    let coachNote: String?

    enum CodingKeys: String, CodingKey {
        case error
        case startTime = "start_time"
        case endTime = "end_time"
        case durationSeconds = "duration_seconds"
        case coachNote = "coach_note"
    }
}

