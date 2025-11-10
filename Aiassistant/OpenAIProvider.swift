import Foundation

struct OpenAIConfig: Codable {
    var apiKey: String
    var baseURL: String
    var organization: String?
    var project: String?
    var model: String
    
    static let defaultBaseURL = "https://api.openai.com/v1"
    static let defaultModel = "gpt-4o"
}

enum OpenAIModel: String, CaseIterable {
    case gpt4 = "gpt-4"
    case gpt35Turbo = "gpt-3.5-turbo"
    case gpt4o = "gpt-4o"
    case gpt4oMini = "gpt-4o-mini"
    
    var displayName: String {
        switch self {
        case .gpt4: return "GPT-4 (Most Capable)"
        case .gpt35Turbo: return "GPT-3.5 Turbo (Faster)"
        case .gpt4o: return "GPT-4o (Optimized)"
        case .gpt4oMini: return "GPT-4o Mini (Lightweight)"
        }
    }
}

class OpenAIProvider: ObservableObject, AIProvider {
    @Published var isProcessing = false
    private var config: OpenAIConfig
    
    init(config: OpenAIConfig) {
        self.config = config
    }
    
    private static func requiresResponsesAPI(for model: String, baseURL: String) -> Bool {
        guard let url = URL(string: baseURL), let host = url.host else {
            return false
        }
        
        // Only OpenAI's public API currently exposes the Responses endpoint.
        let isOpenAIHost = host.contains("openai.com")
        if !isOpenAIHost {
            return false
        }
        
        let lowercased = model.lowercased()
        let responsesPrefixes = ["gpt-4.1", "gpt-5", "o1", "o3"]
        if responsesPrefixes.contains(where: { lowercased.hasPrefix($0) }) {
            return true
        }
        
        let legacyPrefixes = ["gpt-3.5", "gpt-4", "text-davinci", "davinci", "babbage", "ada"]
        if legacyPrefixes.contains(where: { lowercased.hasPrefix($0) }) {
            return false
        }
        
        // Default to the Responses API for unknown future OpenAI models.
        return true
    }
    
    private static func responsesModelSupportsSamplingParameters(_ model: String) -> Bool {
        let lowercased = model.lowercased()
        let unsupportedPrefixes = ["gpt-5", "o1", "o3"]
        if unsupportedPrefixes.contains(where: { lowercased.hasPrefix($0) }) {
            return false
        }
        return true
    }
    
    // --- Helper function to determine MIME type --- 
    private func mimeType(for imageData: Data) -> String {
        // Basic check based on magic bytes (more robust checks are possible)
        if imageData.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) {
            return "image/png"
        } else if imageData.starts(with: [0xFF, 0xD8, 0xFF]) {
            return "image/jpeg"
        } else if imageData.starts(with: [0x47, 0x49, 0x46, 0x38]) {
            return "image/gif"
        } else if imageData.starts(with: [0x52, 0x49, 0x46, 0x46]) && imageData.count > 11 && imageData[8...11] == Data([0x57, 0x45, 0x42, 0x50]) { // RIFF ... WEBP
             return "image/webp"
        } else {
            // Default or further checks needed
            print("Warning: Could not determine precise image MIME type, defaulting to png")
            return "image/png" // Default fallback
        }
    }
    // --- END Helper ---
    
    func processText(systemPrompt: String? = "You are a helpful writing assistant.", userPrompt: String, images: [Data] = [], videos: [Data]? = nil) async throws -> AIResponse {
        // --- REVISED to handle images for vision models --- 
        isProcessing = true
        defer { isProcessing = false }
        
        guard !config.apiKey.isEmpty else {
            throw NSError(domain: "OpenAIAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "API key is missing."])
        }
        
        let baseURL = config.baseURL.isEmpty ? OpenAIConfig.defaultBaseURL : config.baseURL
        let useResponsesAPI = OpenAIProvider.requiresResponsesAPI(for: config.model, baseURL: baseURL)
        let path = useResponsesAPI ? "/responses" : "/chat/completions"
        
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw NSError(domain: "OpenAIAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL."])
        }
        
        // --- Build Message Content --- 
        // --- Re-enabled image handling --- 
        var userMessageContent: [[String: Any]] = []
        // Add text part first
        // --- CORRECTED KEY for text part --- 
        userMessageContent.append(["type": "text", "text": userPrompt]) // Key is "text", not "content"
        // --- END CORRECTION ---
        
        // Add image parts
        for imageData in images {
            let base64Image = imageData.base64EncodedString()
            let mimeType = mimeType(for: imageData)
            userMessageContent.append(
                ["type": "image_url", 
                 "image_url": ["url": "data:\(mimeType);base64,\(base64Image)"]
                ]
            )
        }
        // --- END Build Message Content ---
        
        // --- Updated Request Body for Vision --- 
        // --- Re-enabled image handling in body --- 
        let systemMessage = systemPrompt ?? "You are a helpful writing assistant."
        let requestBody: [String: Any]
        
        if useResponsesAPI {
            var input: [[String: Any]] = []
            if !systemMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                input.append([
                    "role": "system",
                    "content": [
                        ["type": "input_text", "text": systemMessage]
                    ]
                ])
            }
            
            let userContent = userMessageContent.compactMap { part -> [String: Any]? in
                guard let type = part["type"] as? String else { return nil }
                switch type {
                case "text":
                    let text = (part["text"] as? String) ?? ""
                    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                    return ["type": "input_text", "text": text]
                case "image_url":
                    if let imageURL = part["image_url"] {
                        return ["type": "input_image", "image_url": imageURL]
                    }
                    return nil
                default:
                    return nil
                }
            }
            
            input.append([
                "role": "user",
                "content": userContent.isEmpty
                    ? [["type": "input_text", "text": userPrompt]]
                    : userContent
            ])
            
            var responsesBody: [String: Any] = [
                "model": config.model,
                "input": input
            ]
            
            if OpenAIProvider.responsesModelSupportsSamplingParameters(config.model) {
                responsesBody["max_output_tokens"] = 1000
                responsesBody["temperature"] = 0.5
            }
            
            requestBody = responsesBody
        } else {
            requestBody = [
                "model": config.model, // Ensure this is a vision model (e.g., gpt-4o)
                "messages": [
                    ["role": "system", "content": systemMessage],
                    ["role": "user", "content": userMessageContent] // Pass structured content
                    // ["role": "user", "content": userPrompt] // Use array content now
                ],
                 "max_tokens": 1000, // Re-enabled max_tokens
                "temperature": 0.5
            ]
        }
        // --- END Updated Request Body ---
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60 // Increase timeout to 60 seconds for potentially large image uploads
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        
        if let organization = config.organization, !organization.isEmpty {
            request.setValue(organization, forHTTPHeaderField: "OpenAI-Organization")
        }
        
        if let project = config.project, !project.isEmpty {
            request.setValue(project, forHTTPHeaderField: "OpenAI-Project")
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "OpenAIAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid server response."])
        }
        
        if httpResponse.statusCode != 200 {
            if let errorJSON = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
               let errorDict = errorJSON["error"] as? [String: Any],
               let message = errorDict["message"] as? String,
               !message.isEmpty {
                throw NSError(domain: "OpenAIAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
            }
            let fallbackMessage = String(data: data, encoding: .utf8) ?? "Server returned status code \(httpResponse.statusCode)."
            throw NSError(domain: "OpenAIAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: fallbackMessage])
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = try OpenAIProvider.extractContent(from: json, usingResponsesAPI: useResponsesAPI) else {
            throw NSError(domain: "OpenAIAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response."])
        }
        
        // OpenAI response won't contain generated images in this call
        return AIResponse(text: content, images: [])
    }
    
    func cancel() {
        isProcessing = false
    }
    
    private static func extractContent(from json: [String: Any], usingResponsesAPI: Bool) throws -> String? {
        if usingResponsesAPI {
            if let outputText = json["output_text"] as? String,
               !outputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return outputText
            }
            
            if let outputs = json["output"] as? [[String: Any]] {
                let combined = outputs.compactMap { output -> String? in
                    guard let contentItems = output["content"] as? [[String: Any]] else { return nil }
                    let text = contentItems.compactMap { item -> String? in
                        if let text = item["text"] as? String, !text.isEmpty {
                            return text
                        }
                        if let text = item["output_text"] as? String, !text.isEmpty {
                            return text
                        }
                        if let type = item["type"] as? String,
                           type == "output_text",
                           let text = item["text"] as? String,
                           !text.isEmpty {
                            return text
                        }
                        return nil
                    }.joined(separator: "\n")
                    return text.isEmpty ? nil : text
                }.joined(separator: "\n\n")
                
                if !combined.isEmpty {
                    return combined
                }
            }
            
            return nil
        } else {
            guard let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                return nil
            }
            return content
        }
    }
}
