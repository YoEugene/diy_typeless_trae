import Foundation

enum VoiceInlineError: LocalizedError {
    case missingAPIKey(String)
    case invalidURL
    case audioReadFailed
    case emptyResponse
    case unexpectedResponse
    case apiError(String)
    case recordingFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let key):
            return "Missing API key: \(key)"
        case .invalidURL:
            return "Invalid URL"
        case .audioReadFailed:
            return "Failed to read recorded audio file"
        case .emptyResponse:
            return "Empty response from API"
        case .unexpectedResponse:
            return "Unexpected API response format"
        case .apiError(let message):
            return "API error: \(message)"
        case .recordingFailed(let reason):
            return "Recording failed: \(reason)"
        }
    }
}
