import Foundation

enum LocalConfig {
    static let apiBaseURL = URL(string: "https://api.staging.risefitai.com")!

    // For local testing only. Generate with:
    // cd /Users/dongwang/888888/risefit-api
    // go run ./cmd/devtoken
    static let authToken = ""
}
