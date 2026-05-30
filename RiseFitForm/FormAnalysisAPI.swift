import Foundation

final class FormAnalysisAPI {
    var baseURL = LocalConfig.apiBaseURL
    var authToken: String?

    private lazy var decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    func createAnalysis(exercise: Exercise, videoURL: URL) async throws -> FormAnalysis {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: baseURL.appendingPathComponent("form-analyses"))
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        applyAuth(to: &request)

        request.httpBody = try multipartBody(boundary: boundary, exercise: exercise, videoURL: videoURL)
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

    private func multipartBody(boundary: String, exercise: Exercise, videoURL: URL) throws -> Data {
        var data = Data()
        data.appendField(name: "exercise", value: exercise.rawValue, boundary: boundary)
        try data.appendFile(name: "video", fileURL: videoURL, mimeType: "video/mp4", boundary: boundary)
        data.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return data
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

private extension Data {
    mutating func appendField(name: String, value: String, boundary: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }

    mutating func appendFile(name: String, fileURL: URL, mimeType: String, boundary: String) throws {
        let filename = fileURL.lastPathComponent.isEmpty ? "upload.mp4" : fileURL.lastPathComponent
        let mimeType = fileURL.pathExtension.lowercased() == "mov" ? "video/quicktime" : mimeType
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        append(try Data(contentsOf: fileURL))
        append("\r\n".data(using: .utf8)!)
    }
}
