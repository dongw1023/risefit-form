import Foundation

final class FormAnalysisAPI {
    var baseURL = LocalConfig.apiBaseURL
    var authToken: String?

    private lazy var decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private let encoder = JSONEncoder()

    func createAnalysis(exercise: Exercise, videoURL: URL) async throws -> FormAnalysis {
        let upload = try await createUploadURL(filename: videoURL.lastPathComponent, contentType: contentType(for: videoURL))
        try await uploadVideo(videoURL, to: upload.uploadURL, contentType: upload.contentType)
        return try await createAnalysisFromUploadedVideo(exercise: exercise, upload: upload)
    }

    private func createUploadURL(filename: String, contentType: String) async throws -> FormUploadURL {
        var request = URLRequest(url: baseURL.appendingPathComponent("form-analyses/upload-url"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuth(to: &request)
        request.httpBody = try encoder.encode(FormUploadURLRequest(filename: filename, contentType: contentType))

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try decoder.decode(FormUploadURL.self, from: data)
    }

    private func uploadVideo(_ videoURL: URL, to uploadURL: URL, contentType: String) async throws {
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.upload(for: request, fromFile: videoURL)
        try validateUpload(response: response, data: data)
    }

    private func createAnalysisFromUploadedVideo(exercise: Exercise, upload: FormUploadURL) async throws -> FormAnalysis {
        var request = URLRequest(url: baseURL.appendingPathComponent("form-analyses/from-upload"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuth(to: &request)
        request.httpBody = try encoder.encode(CreateUploadedAnalysisRequest(
            analysisID: upload.analysisID,
            exercise: exercise.rawValue,
            objectName: upload.objectName
        ))

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try decoder.decode(FormAnalysis.self, from: data)
    }

    func fetchAnalysis(id: UUID) async throws -> FormAnalysis {
        var request = URLRequest(url: baseURL.appendingPathComponent("form-analyses/\(id.uuidString)"))
        applyAuth(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try decoder.decode(FormAnalysis.self, from: data)
    }

    func listAnalyses(limit: Int = 20) async throws -> [FormAnalysis] {
        var components = URLComponents(url: baseURL.appendingPathComponent("form-analyses"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "skip", value: "0"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]

        var request = URLRequest(url: components.url!)
        applyAuth(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try decoder.decode(FormAnalysisListResponse.self, from: data).formAnalyses
    }

    func reanalyzeAnalysis(id: UUID) async throws -> FormAnalysis {
        var request = URLRequest(url: baseURL.appendingPathComponent("form-analyses/\(id.uuidString)/analyze"))
        request.httpMethod = "POST"
        applyAuth(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try decoder.decode(FormAnalysis.self, from: data)
    }

    func analysedVideoURL(for analysis: FormAnalysis) -> URL? {
        signedVideoURL(path: analysis.analysedVideoURL)
    }

    func originalVideoURL(for analysis: FormAnalysis) -> URL? {
        signedVideoURL(path: analysis.originalVideoURL)
    }

    private func signedVideoURL(path: String?) -> URL? {
        guard let path else { return nil }
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else { return nil }
        guard let authToken, var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }

        var queryItems = components.queryItems ?? []
        queryItems.append(URLQueryItem(name: "token", value: authToken))
        components.queryItems = queryItems
        return components.url
    }

    private func applyAuth(to request: inout URLRequest) {
        if let authToken {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 413 {
                throw APIError.local("The video is too large to upload. Please trim it to a shorter clip and try again.")
            }
            let message = String(data: data, encoding: .utf8) ?? "Request failed"
            throw APIError.server(status: httpResponse.statusCode, message: message)
        }
    }

    private func validateUpload(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Upload failed"
            throw APIError.server(status: httpResponse.statusCode, message: message)
        }
    }

    private func contentType(for videoURL: URL) -> String {
        switch videoURL.pathExtension.lowercased() {
        case "mov":
            return "video/quicktime"
        case "m4v":
            return "video/x-m4v"
        default:
            return "video/mp4"
        }
    }
}

private struct FormUploadURLRequest: Encodable {
    let filename: String
    let contentType: String

    enum CodingKeys: String, CodingKey {
        case filename
        case contentType = "content_type"
    }
}

private struct FormUploadURL: Decodable {
    let analysisID: UUID
    let objectName: String
    let uploadURL: URL
    let contentType: String
    let expiresAt: String

    enum CodingKeys: String, CodingKey {
        case analysisID = "analysis_id"
        case objectName = "object_name"
        case uploadURL = "upload_url"
        case contentType = "content_type"
        case expiresAt = "expires_at"
    }
}

private struct CreateUploadedAnalysisRequest: Encodable {
    let analysisID: UUID
    let exercise: String
    let objectName: String

    enum CodingKeys: String, CodingKey {
        case analysisID = "analysis_id"
        case exercise
        case objectName = "object_name"
    }
}

private struct FormAnalysisListResponse: Decodable {
    let formAnalyses: [FormAnalysis]

    enum CodingKeys: String, CodingKey {
        case formAnalyses = "form_analyses"
    }
}

enum APIError: LocalizedError {
    case server(status: Int, message: String)
    case local(String)

    var errorDescription: String? {
        switch self {
        case .server(let status, let message):
            return "Server error \(status): \(message)"
        case .local(let message):
            return message
        }
    }
}
