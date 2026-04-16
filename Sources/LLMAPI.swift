import Foundation

struct LLMAPI {
    private static let systemPrompt = "You are a helpful assistant. Answer concisely. Keep your response short and suitable for pasting inline."

    static func ask(question: String, completion: @escaping (Result<String, Error>) -> Void) {
        if let anthropicKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] {
            askClaude(question: question, apiKey: anthropicKey, completion: completion)
        } else if let openaiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] {
            askGPT(question: question, apiKey: openaiKey, completion: completion)
        } else {
            completion(.failure(VoiceInlineError.missingAPIKey("OPENAI_API_KEY or ANTHROPIC_API_KEY")))
        }
    }

    private static func askGPT(question: String, apiKey: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            completion(.failure(VoiceInlineError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": question],
            ],
            "max_tokens": 512,
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: request) { data, _, error in
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
                    if let choices = json["choices"] as? [[String: Any]],
                       let first = choices.first,
                       let message = first["message"] as? [String: Any],
                       let content = message["content"] as? String {
                        completion(.success(content.trimmingCharacters(in: .whitespacesAndNewlines)))
                    } else if let errorObj = json["error"] as? [String: Any],
                              let message = errorObj["message"] as? String {
                        completion(.failure(VoiceInlineError.apiError(message)))
                    } else {
                        completion(.failure(VoiceInlineError.unexpectedResponse))
                    }
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    private static func askClaude(question: String, apiKey: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            completion(.failure(VoiceInlineError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 512,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": question],
            ],
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: request) { data, _, error in
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
                    if let content = json["content"] as? [[String: Any]],
                       let first = content.first,
                       let text = first["text"] as? String {
                        completion(.success(text.trimmingCharacters(in: .whitespacesAndNewlines)))
                    } else if let errorObj = json["error"] as? [String: Any],
                              let message = errorObj["message"] as? String {
                        completion(.failure(VoiceInlineError.apiError(message)))
                    } else {
                        completion(.failure(VoiceInlineError.unexpectedResponse))
                    }
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
