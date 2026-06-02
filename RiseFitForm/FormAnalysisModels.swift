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

enum FormAnalysisFeedbackRating: String, CaseIterable, Identifiable {
    case correct
    case wrong
    case notSure = "not_sure"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .correct:
            return "Looks correct"
        case .wrong:
            return "Looks wrong"
        case .notSure:
            return "Not sure"
        }
    }

    var icon: String {
        switch self {
        case .correct:
            return "checkmark.circle.fill"
        case .wrong:
            return "xmark.circle.fill"
        case .notSure:
            return "questionmark.circle.fill"
        }
    }
}

struct FormAnalysis: Identifiable, Decodable {
    let id: UUID
    let exercise: String
    let status: FormAnalysisStatus
    let originalVideoURL: String?
    let analysedVideoURL: String?
    let report: FormAnalysisReport?
    let formScore: Int?
    let formGrade: String?
    let repCount: Int?
    let primaryIssue: String?
    let issueCount: Int?
    let viewHealth: Int?
    let analysisQuality: String?
    let confidence: Double?
    let trainingConsent: Bool?
    let trainingConsentAt: Date?
    let trainingUsageStatus: String?
    let error: String?
    let completedAt: Date?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case exercise
        case status
        case originalVideoURL = "original_video_url"
        case analysedVideoURL = "analysed_video_url"
        case report
        case formScore = "form_score"
        case formGrade = "form_grade"
        case repCount = "rep_count"
        case primaryIssue = "primary_issue"
        case issueCount = "issue_count"
        case viewHealth = "view_health"
        case analysisQuality = "analysis_quality"
        case confidence
        case trainingConsent = "training_consent"
        case trainingConsentAt = "training_consent_at"
        case trainingUsageStatus = "training_usage_status"
        case error
        case completedAt = "completed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct FormAnalysisReport: Decodable {
    let exercise: String?
    let formGrade: String?
    let formScore: Double?
    let summary: FormAnalysisSummary?
    let repCount: Int?
    let primaryIssue: String?
    let issueCount: Int?
    let analysisQuality: String?
    let confidence: Double?
    let detectedEvents: [DetectedFormEvent]?
    let reps: [FormRep]?
    let viewHealth: Double?
    let totalDuration: Double?
    let video: VideoMetadata?

    enum CodingKeys: String, CodingKey {
        case exercise
        case formGrade = "form_grade"
        case formScore = "form_score"
        case summary
        case repCount = "rep_count"
        case primaryIssue = "primary_issue"
        case issueCount = "issue_count"
        case analysisQuality = "analysis_quality"
        case confidence
        case detectedEvents = "detected_events"
        case reps
        case viewHealth = "view_health"
        case totalDuration = "total_duration"
        case video
    }
}

struct FormAnalysisSummary: Decodable {
    let repCount: Int?
    let primaryIssue: String?
    let issueCount: Int?
    let analysisQuality: String?
    let confidence: Double?

    enum CodingKeys: String, CodingKey {
        case repCount = "rep_count"
        case primaryIssue = "primary_issue"
        case issueCount = "issue_count"
        case analysisQuality = "analysis_quality"
        case confidence
    }
}

struct FormRep: Decodable, Identifiable {
    var id: Int { repIndex }
    let repIndex: Int
    let startTime: Double?
    let endTime: Double?
    let durationSeconds: Double?
    let tempo: RepTempo?
    let issues: [String]?

    enum CodingKeys: String, CodingKey {
        case repIndex = "rep_index"
        case startTime = "start_time"
        case endTime = "end_time"
        case durationSeconds = "duration_seconds"
        case tempo
        case issues
    }
}

struct RepTempo: Decodable {
    let eccentric: Double?
    let pause: Double?
    let concentric: Double?
}

struct VideoMetadata: Decodable {
    let fps: Double?
    let processedFPS: Double?
    let frameCount: Int?
    let processedFrameCount: Int?
    let durationSeconds: Double?

    enum CodingKeys: String, CodingKey {
        case fps
        case processedFPS = "processed_fps"
        case frameCount = "frame_count"
        case processedFrameCount = "processed_frame_count"
        case durationSeconds = "duration_seconds"
    }
}

struct DetectedFormEvent: Decodable, Identifiable {
    let id = UUID()
    let type: String?
    let error: String
    let severity: String?
    let repIndex: Int?
    let phase: String?
    let startTime: Double?
    let endTime: Double?
    let durationSeconds: Double?
    let confidence: Double?
    let coachNote: String?

    enum CodingKeys: String, CodingKey {
        case type
        case error
        case severity
        case repIndex = "rep_index"
        case phase
        case startTime = "start_time"
        case endTime = "end_time"
        case durationSeconds = "duration_seconds"
        case confidence
        case coachNote = "coach_note"
    }
}
