import Foundation

final class FormAnalysisAPI {
    var baseURL = LocalConfig.apiBaseURL
    var authToken: String? = LocalConfig.authToken.isEmpty ? nil : LocalConfig.authToken

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

    func analysedVideoURL(for analysis: FormAnalysis) -> URL? {
        guard let path = analysis.analysedVideoURL else { return nil }
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

enum APIError: LocalizedError {
    case server(status: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .server(let status, let message):
            return "Server error \(status): \(message)"
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
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        append(try Data(contentsOf: fileURL))
        append("\r\n".data(using: .utf8)!)
    }
}
