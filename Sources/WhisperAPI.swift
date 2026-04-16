import Foundation

enum WhisperEndpoint {
    case transcription
    case translation
}

struct WhisperAPI {
    static func process(audioURL: URL, endpoint: WhisperEndpoint, completion: @escaping (Result<String, Error>) -> Void) {
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
            completion(.failure(VoiceInlineError.missingAPIKey("OPENAI_API_KEY")))
            return
        }

        let path: String
        switch endpoint {
        case .transcription:
            path = "https://api.openai.com/v1/audio/transcriptions"
        case .translation:
            path = "https://api.openai.com/v1/audio/translations"
        }

        guard let url = URL(string: path) else {
            completion(.failure(VoiceInlineError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        guard let audioData = try? Data(contentsOf: audioURL) else {
            completion(.failure(VoiceInlineError.audioReadFailed))
            return
        }

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(VoiceInlineError.emptyResponse))
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let text = json["text"] as? String {
                        completion(.success(text))
                    } else if let errorObj = json["error"] as? [String: Any],
                              let message = errorObj["message"] as? String {
                        completion(.failure(VoiceInlineError.apiError(message)))
                    } else {
                        completion(.failure(VoiceInlineError.unexpectedResponse))
                    }
                } else {
                    completion(.failure(VoiceInlineError.unexpectedResponse))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
