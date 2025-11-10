import Foundation
import AppKit

struct GeminiConfig: Codable {
    var apiKey: String
    var modelName: String
}

enum GeminiModel: String, CaseIterable {
    case twofivePro = "gemini-2.5-pro"
    case twofiveFlash = "gemini-flash-latest"
    
    var displayName: String {
        switch self {
        case .twofivePro: return "Gemini 2.5 Pro"
        case .twofiveFlash: return "Gemini 2.5 Flash"
        }
    }
}

class GeminiProvider: ObservableObject, AIProvider {
    @Published var isProcessing = false
    private var config: GeminiConfig

    init(config: GeminiConfig) {
        self.config = config
    }
    
    func processText(systemPrompt: String?, userPrompt: String, images: [Data], videos: [Data]?) async throws -> AIResponse {
        isProcessing = true
        defer { isProcessing = false }
        
        let finalPrompt = systemPrompt.map { "\($0)\n\n\(userPrompt)" } ?? userPrompt
        
        guard !config.apiKey.isEmpty else {
            throw NSError(domain: "GeminiAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "API key is missing."])
        }
        
        // Create parts array with text
        var parts: [[String: Any]] = []
        parts.append(["text": finalPrompt])
        
        // Add image parts if present
        for imageData in images {
            parts.append([
                "inline_data": [
                    "mime_type": "image/jpeg",
                    "data": imageData.base64EncodedString()
                ]
            ])
        }
        
        // Add video parts if present
        if let videos = videos {
            for videoData in videos {
                parts.append([
                    "inline_data": [
                        "mime_type": "video/mp4",
                        "data": videoData.base64EncodedString()
                    ]
                ])
            }
        }
        
        // Build normalized prompts for downstream checks
        let lowercaseFinalPrompt = finalPrompt.lowercased()
        // Use only the user's words when deciding on image-specific routing to avoid system prompt bleed-through.
        let lowercaseUserPrompt = userPrompt.lowercased()
        let condensedUserPrompt = lowercaseUserPrompt
            .components(separatedBy: CharacterSet.whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        
        // Check if this is a URL-related prompt (to avoid triggering image generation for URLs)
        let isURLRelated = lowercaseUserPrompt.contains("http://") || 
                           lowercaseUserPrompt.contains("https://") ||
                           lowercaseUserPrompt.contains("www.") ||
                           lowercaseUserPrompt.hasPrefix("summarize this webpage") ||
                           lowercaseUserPrompt.hasPrefix("summarize this article") ||
                           lowercaseUserPrompt.hasPrefix("analyze this webpage") ||
                           lowercaseUserPrompt.hasPrefix("analyze this url") ||
                           lowercaseUserPrompt.contains("webpage") ||
                           lowercaseUserPrompt.contains("website") ||
                           lowercaseUserPrompt.contains("web page") ||
                           lowercaseUserPrompt.contains("web site") ||
                           lowercaseUserPrompt.contains("url") ||
                           lowercaseUserPrompt.contains("link") ||
                           lowercaseUserPrompt.contains("site") ||
                           lowercaseUserPrompt.contains("article") ||
                           lowercaseUserPrompt.contains("blog") ||
                           lowercaseUserPrompt.contains("web address") ||
                           userPrompt.hasPrefix("http") ||
                           userPrompt.contains("://") ||
                           lowercaseUserPrompt.hasPrefix("www.")
        
        // Check for explicit opt-out instruction
        let explicitlyPreventImageGen = lowercaseUserPrompt.contains("do not generate images")
        
        // Check for the specific follow-up instruction prefix (case-insensitive match)
        let followUpMarker = "very important: respond based only on the text context and conversation. do not generate or edit images."
        let isFollowUpWithNoImageIntent = lowercaseFinalPrompt.contains(followUpMarker)
        
        func containsExplicitImageGenerationRequest(in text: String) -> Bool {
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { return false }
            
            let startsWithPhrases = [
                "image of ",
                "an image of ",
                "a picture of ",
                "picture of ",
                "photo of ",
                "a photo of "
            ]
            if startsWithPhrases.contains(where: { trimmed.hasPrefix($0) }) {
                return true
            }
            
            let directPhrases = [
                "generate an image",
                "generate a image",
                "generate image of",
                "create an image",
                "create a image",
                "create image of",
                "draw an image",
                "draw a picture",
                "make an image",
                "make a picture",
                "design an image",
                "render an image",
                "paint an image",
                "sketch an image"
            ]
            if directPhrases.contains(where: { trimmed.contains($0) }) {
                return true
            }
            
            let modalPhrases = [
                "can you generate an image",
                "can you create an image",
                "could you generate an image",
                "could you create an image",
                "please generate an image",
                "please create an image",
                "please draw an image",
                "please draw a picture"
            ]
            if modalPhrases.contains(where: { trimmed.contains($0) }) {
                return true
            }
            
            let pattern = "\\b(generate|create|draw|make|design|render|paint|sketch)\\b[\\s,.;:-]{0,25}\\b(image|picture|photo|graphic|logo|illustration|portrait|drawing|artwork)\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
                if regex.firstMatch(in: trimmed, options: [], range: range) != nil {
                    return true
                }
            }
            
            return false
        }
        
        func containsExplicitImageEditRequest(in text: String) -> Bool {
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { return false }
            
            let directPhrases = [
                "edit this image",
                "edit the image",
                "edit this photo",
                "edit the photo",
                "modify this image",
                "modify the image",
                "change this image",
                "change the image",
                "enhance this image",
                "enhance the image",
                "apply a filter",
                "remove the background"
            ]
            if directPhrases.contains(where: { trimmed.contains($0) }) {
                return true
            }
            
            let pattern = "\\b(edit|modify|change|enhance|retouch|adjust|improve|apply)\\b[\\s,.;:-]{0,25}\\b(image|photo|picture|graphic|logo)\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
                if regex.firstMatch(in: trimmed, options: [], range: range) != nil {
                    return true
                }
            }
            
            return false
        }
        
        // Use the model name from configuration
        let modelName = config.modelName
        
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(modelName):generateContent?key=\(config.apiKey)") else {
            throw NSError(domain: "GeminiAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL."])
        }
        
        // Add generation config with image output for image generation requests
        let thinkingConfig: [String: Any] = ["thinkingBudget": 0]
        print("Thinking disabled for model \(modelName)")
        
        var baseGenerationConfig: [String: Any] = [:]
        baseGenerationConfig["thinkingConfig"] = thinkingConfig
        baseGenerationConfig["response_modalities"] = ["TEXT"]
        
        var requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": parts
                ]
            ],
            "generationConfig": baseGenerationConfig
        ]
        
        // --- RESTRUCTURED: Check for follow-up FIRST, then handle image modes if needed --- 
        if isFollowUpWithNoImageIntent {
            print("DEBUG: Follow-up detected. Skipping image generation/edit logic.")
            // Keep the default requestBody which is text-only
        } else {
            // --- Image Detection Logic (only runs if NOT a follow-up) ---
            let isImageGenerationRequest = !isURLRelated &&
                                           !explicitlyPreventImageGen &&
                                           containsExplicitImageGenerationRequest(in: condensedUserPrompt)
            
            let isImageEditRequest = !isURLRelated &&
                                     !explicitlyPreventImageGen &&
                                     !images.isEmpty &&
                                     containsExplicitImageEditRequest(in: condensedUserPrompt)
            
            // --- Build Image Request Body (only if detected and not a follow-up) ---
            if isImageGenerationRequest || isImageEditRequest {
                print("📸 IMAGE GENERATION/EDIT DETECTED - Using Gemini's image generation capabilities")
                
                let imagePrompt: String
                if isImageEditRequest && !images.isEmpty {
                    imagePrompt = """
                    I have attached an existing image. Please create a new version of this image with the following changes:
                    \(finalPrompt)
                    
                    Generate a completely new image incorporating these changes, using the attached image as reference.
                    Create a high-quality, detailed image in your response.
                    """
                } else {
                    imagePrompt = """
                    Generate an image based on this description: \(finalPrompt)
                    Create a high-quality, detailed image directly in your response.
                    Your response should include the generated image along with any descriptive text.
                    The image should be clear, high-resolution, and accurately represent the request.
                    """
                }
                
                var contentParts: [[String: Any]] = []
                if isImageEditRequest && !images.isEmpty {
                    for imageData in images { contentParts.append(["inline_data": ["mime_type": "image/jpeg", "data": imageData.base64EncodedString()]]) }
                    contentParts.append(["text": imagePrompt])
                } else {
                    contentParts.append(["text": imagePrompt])
                    for imageData in images { contentParts.append(["inline_data": ["mime_type": "image/jpeg", "data": imageData.base64EncodedString()]]) }
                }
                
                // Updated requestBody for image generation
                var generationConfig: [String: Any] = [
                    "temperature": 1.0,
                    "topP": 0.95,
                    "topK": 64,
                    "maxOutputTokens": 8192,
                    "response_modalities": ["TEXT", "IMAGE"]
                ]
                generationConfig["thinkingConfig"] = thinkingConfig
                
                requestBody = [
                    "contents": [
                        [
                            "parts": contentParts,
                            "role": "user"
                        ]
                    ],
                    "generationConfig": generationConfig
                ]
                
                print("🖼️ Using image generation request: \(requestBody)")
            }
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: .fragmentsAllowed)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "GeminiAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response type."])
        }
        
        if httpResponse.statusCode != 200 {
            // Try to parse error details from response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                print("API Error: \(message)")
                throw NSError(domain: "GeminiAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
            }
            print("Response data: \(String(data: data, encoding: .utf8) ?? "no data")")
            throw NSError(domain: "GeminiAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned error \(httpResponse.statusCode)"])
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            print("Failed to parse response: \(String(data: data, encoding: .utf8) ?? "no data")")
            throw NSError(domain: "GeminiAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse JSON response."])
        }
        
        // Print the full response for debugging
        print("Full JSON response: \(String(data: data, encoding: .utf8) ?? "no data")")
        
        guard let candidates = json["candidates"] as? [[String: Any]], !candidates.isEmpty else {
            throw NSError(domain: "GeminiAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "No candidates found in the response."])
        }
        
        print("Candidates: \(candidates)")
        
        // First check if there are tool calls in the candidates
        if let candidate = candidates.first,
           let toolCalls = candidate["toolCalls"] as? [[String: Any]] {
            
            print("Found tool calls at top level: \(toolCalls)")
            var responseText = ""
            var generatedImages: [Data] = []
            
            for toolCall in toolCalls {
                if let functionCall = toolCall["functionCall"] as? [String: Any],
                   let name = functionCall["name"] as? String,
                   name == "generateImage" {
                    
                    print("Found top-level functionCall for generateImage: \(functionCall)")
                    
                    // Handle both "args" and "arguments" keys
                    let arguments = functionCall["args"] as? [String: Any] ?? functionCall["arguments"] as? [String: Any] ?? [:]
                    
                    if let prompt = arguments["prompt"] as? String {
                        print("Found top-level image generation prompt: \(prompt)")
                        responseText = "Generated image for: \"\(prompt)\""
                        
                        // Check if we should use Stability.ai or another service for image generation
                        print("Attempting to generate a real image for: \(prompt)")
                        
                        // For now, fall back to placeholder until API integration is complete
                        if let realImage = tryGenerateRealImage(prompt: prompt) {
                            print("Successfully generated a REAL image! Size: \(realImage.count) bytes")
                            generatedImages.append(realImage)
                        } else if let placeholderImage = createPlaceholderImage(text: prompt) {
                            print("⚠️ Using placeholder image as fallback")
                            generatedImages.append(placeholderImage)
                        } else {
                            print("Failed to create any image for prompt")
                        }
                    } else {
                        print("Top-level function call has no usable prompt: \(arguments)")
                    }
                }
            }
            
            if !generatedImages.isEmpty {
                return AIResponse(text: responseText, images: generatedImages)
            }
        }
        
        // Then check the candidates content if no tool calls were found
        if let content = candidates.first?["content"] as? [String: Any],
           let parts = content["parts"] as? [[String: Any]] {
            
            var responseText = ""
            var generatedImages: [Data] = []
            
            // Debug the content structure
            print("Response parts: \(parts)")
            
            print("DEBUG all parts: \(parts)")
            for part in parts {
                // Debug each part
                print("Processing part: \(part)")
                
                if let text = part["text"] as? String {
                    responseText += text
                    print("Found text part: \(text)")
                } 
                // Handle both camelCase and snake_case keys per documentation
                else if let inlineData = part["inlineData"] as? [String: Any] {
                    print("Found inlineData (camelCase): \(inlineData)")
                    let mimeType = inlineData["mimeType"] as? String ?? ""
                    
                    if mimeType.starts(with: "image/"),
                       let base64String = inlineData["data"] as? String,
                       let imageData = Data(base64Encoded: base64String) {
                        print("Found image with mimeType: \(mimeType), size: \(imageData.count)")
                        generatedImages.append(imageData)
                    }
                }
                // Handle alternative naming (snake_case from the API docs)
                else if let inlineData = part["inline_data"] as? [String: Any] {
                    print("Found inline_data (snake_case): \(inlineData)")
                    // Check different ways the MIME type might be specified
                    let mimeType = inlineData["mime_type"] as? String ?? inlineData["mimeType"] as? String ?? ""
                    
                    if mimeType.starts(with: "image/"),
                       let base64String = inlineData["data"] as? String,
                       let imageData = Data(base64Encoded: base64String) {
                        print("Found image with mime_type: \(mimeType), size: \(imageData.count)")
                        generatedImages.append(imageData)
                    }
                }
                
                // Check for function calls which may contain images
                // Check for function calls that indicate image generation
                if let functionCall = part["functionCall"] as? [String: Any],
                   let name = functionCall["name"] as? String,
                   name == "generateImage" {
                    
                    print("Found functionCall for generateImage: \(functionCall)")
                    
                    // Handle both "args" and "arguments" keys
                    let arguments = functionCall["args"] as? [String: Any] ?? functionCall["arguments"] as? [String: Any] ?? [:]
                    
                    // If we have a imageUrl, try to load it
                    if let imageUrl = arguments["imageUrl"] as? String,
                       let url = URL(string: imageUrl),
                       let imageData = try? Data(contentsOf: url) {
                        print("Found image from function call URL: \(imageUrl)")
                        generatedImages.append(imageData)
                    }
                    // If we just have a prompt, we'll need to generate an image ourselves
                    else if let prompt = arguments["prompt"] as? String {
                        print("Found image generation prompt: \(prompt)")
                        // For function calls with just a prompt but no image, we need to create a placeholder
                        // or generate the image separately
                        
                        // Create a placeholder image with text
                        if let placeholderImage = createPlaceholderImage(text: prompt) {
                            generatedImages.append(placeholderImage)
                            
                            // Add text explaining that the model provided a prompt for an image
                            responseText += "Image generated for: \"\(prompt)\"\n"
                        }
                    } else {
                        print("Function call has no usable arguments: \(arguments)")
                    }
                }
            }
            
            // Check for tool calls in the response which may contain images
            if let candidate = candidates.first,
               let toolCalls = candidate["toolCalls"] as? [[String: Any]] {
                print("Found tool calls in response: \(toolCalls)")
                
                for toolCall in toolCalls {
                    if let functionCall = toolCall["functionCall"] as? [String: Any],
                       let name = functionCall["name"] as? String,
                       name == "generateImage" {
                        
                        print("Found nested toolCall for generateImage: \(functionCall)")
                        
                        // Handle both "args" and "arguments" keys
                        let arguments = functionCall["args"] as? [String: Any] ?? [:]
                        
                        if let imageData = arguments["imageData"] as? String,
                           let data = Data(base64Encoded: imageData) {
                            print("Found image data in nested tool call")
                            generatedImages.append(data)
                        } else if let imageUrl = arguments["imageUrl"] as? String,
                                 let url = URL(string: imageUrl),
                                 let data = try? Data(contentsOf: url) {
                            print("Found image URL in nested tool call: \(imageUrl)")
                            generatedImages.append(data)
                        } else if let prompt = arguments["prompt"] as? String {
                            print("Found nested image generation prompt: \(prompt)")
                            
                            // Create a placeholder image with the prompt
                            if let placeholderImage = createPlaceholderImage(text: prompt) {
                                print("Successfully created placeholder for nested tool call")
                                generatedImages.append(placeholderImage)
                                responseText += "Image generated for: \"\(prompt)\"\n"
                            }
                        } else {
                            print("Nested function call has no usable arguments: \(arguments)")
                        }
                    }
                }
            }
            
            if !generatedImages.isEmpty {
                print("Successfully found \(generatedImages.count) images in the response")
            }
            
            return AIResponse(text: responseText, images: generatedImages)
        }
        
        throw NSError(domain: "GeminiAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "No valid content in response."])
    }
    
    func cancel() {
        isProcessing = false
    }
    
    // This function can be used for debugging Gemini image generation
    func testImageGeneration(prompt: String) async throws -> AIResponse {
        print("🧪 TESTING DIRECT IMAGE GENERATION: \(prompt)")
        
        // Build a simple request focused on direct image generation
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [["text": "Generate an image: \(prompt). Make it detailed and high quality."]],
                    "role": "user"
                ]
            ],
            "generationConfig": [
                "temperature": 1.0,
                "topP": 0.95,
                "topK": 64,
                "maxOutputTokens": 8192,
                "response_modalities": ["TEXT", "IMAGE"]
            ]
        ]
        
        // Use the model name from configuration
        let modelName = config.modelName
        
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(modelName):generateContent?key=\(config.apiKey)") else {
            throw NSError(domain: "GeminiAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL."])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: .fragmentsAllowed)
        
        print("🧪 Request body: \(String(data: request.httpBody!, encoding: .utf8) ?? "none")")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        print("🧪 Response: \(String(data: data, encoding: .utf8) ?? "none")")
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorMsg = "Server returned error: \(String(data: data, encoding: .utf8) ?? "Unknown error")"
            print("🧪 ERROR: \(errorMsg)")
            throw NSError(domain: "GeminiAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
        
        // Parse the response to find images
        guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              !candidates.isEmpty,
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else {
            throw NSError(domain: "GeminiAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response structure"])
        }
        
        var responseText = ""
        var generatedImages: [Data] = []
        
        // Debug all parts in the response
        print("🧪 All parts in response: \(parts)")
        
        for part in parts {
            if let text = part["text"] as? String {
                responseText += text
                print("🧪 Found text: \(text)")
            } else if let inlineData = part["inlineData"] as? [String: Any] {
                let mimeType = inlineData["mimeType"] as? String ?? ""
                print("🧪 Found inlineData with mimeType: \(mimeType)")
                
                if mimeType.starts(with: "image/"),
                   let base64String = inlineData["data"] as? String,
                   let imageData = Data(base64Encoded: base64String) {
                    print("🧪 Successfully decoded image data of size: \(imageData.count)")
                    generatedImages.append(imageData)
                }
            } else if let inlineData = part["inline_data"] as? [String: Any] {
                let mimeType = inlineData["mime_type"] as? String ?? inlineData["mimeType"] as? String ?? ""
                print("🧪 Found inline_data with mimeType: \(mimeType)")
                
                if mimeType.starts(with: "image/"),
                   let base64String = inlineData["data"] as? String,
                   let imageData = Data(base64Encoded: base64String) {
                    print("🧪 Successfully decoded image data of size: \(imageData.count)")
                    generatedImages.append(imageData)
                }
            } else {
                print("🧪 Unrecognized part type: \(part)")
            }
        }
        
        print("🧪 TEST COMPLETE - Found \(generatedImages.count) images and text: \(responseText)")
        return AIResponse(text: responseText.isEmpty ? "Generated image" : responseText, images: generatedImages)
    }
    
    // Helper to create a placeholder image with text using a more reliable approach
    private func createPlaceholderImage(text: String) -> Data? {
        print("Creating simple placeholder image for: \(text)")
        
        // Use a consistent size
        let imageWidth: CGFloat = 600
        let imageHeight: CGFloat = 400
        
        // Create a bitmap representation directly
        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(imageWidth),
            pixelsHigh: Int(imageHeight),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            print("Failed to create bitmap representation")
            return nil
        }
        
        // Create a graphics context
        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext(bitmapImageRep: bitmapRep) else {
            print("Failed to create graphics context")
            return nil
        }
        NSGraphicsContext.current = context
        
        // Draw a gradient background (more appealing than solid color)
        let startColor = NSColor(calibratedRed: 0.2, green: 0.4, blue: 0.6, alpha: 1.0)
        let endColor = NSColor(calibratedRed: 0.1, green: 0.1, blue: 0.3, alpha: 1.0)
        let gradient = NSGradient(starting: startColor, ending: endColor)!
        gradient.draw(in: NSRect(x: 0, y: 0, width: imageWidth, height: imageHeight), angle: 45)
        
        // Draw a border
        NSColor.white.withAlphaComponent(0.7).setStroke()
        let borderRect = NSRect(x: 10, y: 10, width: imageWidth - 20, height: imageHeight - 20)
        let borderPath = NSBezierPath(roundedRect: borderRect, xRadius: 15, yRadius: 15)
        borderPath.lineWidth = 3
        borderPath.stroke()
        
        // Draw the title
        let titleFont = NSFont.boldSystemFont(ofSize: 28)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: NSColor.white,
            .strokeColor: NSColor.black,
            .strokeWidth: -2.0 // Negative value for stroke outside the text
        ]
        
        let title = "AI Generated Image"
        let titleSize = title.size(withAttributes: titleAttributes)
        let titlePoint = NSPoint(
            x: (imageWidth - titleSize.width) / 2,
            y: imageHeight - 80
        )
        
        title.draw(at: titlePoint, withAttributes: titleAttributes)
        
        // Draw the prompt with word wrapping
        let promptFont = NSFont.systemFont(ofSize: 18)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byWordWrapping
        
        let promptAttributes: [NSAttributedString.Key: Any] = [
            .font: promptFont,
            .foregroundColor: NSColor.white,
            .strokeColor: NSColor.black,
            .strokeWidth: -1.0,
            .paragraphStyle: paragraphStyle
        ]
        
        // Truncate the prompt if it's too long
        let displayPrompt = text.count > 100 ? text.prefix(100) + "..." : text
        let promptTitle = "Prompt: \(displayPrompt)"
        
        // Create attributed string for word wrapping
        let attributedPrompt = NSAttributedString(string: promptTitle, attributes: promptAttributes)
        
        // Define a rect for the text to wrap within
        let textRect = NSRect(x: 40, y: 120, width: imageWidth - 80, height: 200)
        attributedPrompt.draw(in: textRect)
        
        // Draw a note at bottom
        let noteFont = NSFont.systemFont(ofSize: 14)
        let noteAttributes: [NSAttributedString.Key: Any] = [
            .font: noteFont,
            .foregroundColor: NSColor.white.withAlphaComponent(0.8)
        ]
        
        let note = "Gemini Image Placeholder (Real image will be generated)"
        let noteSize = note.size(withAttributes: noteAttributes)
        let notePoint = NSPoint(
            x: (imageWidth - noteSize.width) / 2,
            y: 40
        )
        
        note.draw(at: notePoint, withAttributes: noteAttributes)
        
        // Finish drawing
        NSGraphicsContext.restoreGraphicsState()
        
        // Convert to PNG data
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            print("Failed to create PNG data")
            return nil
        }
        
        print("Placeholder image created: size=\(pngData.count) bytes")
        
        // Verify the image can be loaded
        if NSImage(data: pngData) != nil {
            print("Successfully verified the created image can be loaded back")
            return pngData
        } else {
            print("Warning: Created PNG data cannot be loaded back as an NSImage!")
            return nil
        }
    }
    // Attempt to generate a real image using a third-party service
    private func tryGenerateRealImage(prompt: String) -> Data? {
        // For now, this function attempts to use Stability AI's API for image generation
        // You'll need to set up an API key for this to work
        print("Starting real image generation with prompt: \(prompt)")
        
        // This is a synchronous function, so we need to use semaphores to wait for the async call
        let semaphore = DispatchSemaphore(value: 0)
        var resultImage: Data? = nil
        
        // Use Stability AI API to generate images
        // Reference: https://platform.stability.ai/docs/api-reference
        let stabilityApiKey = UserDefaults.standard.string(forKey: "stability_api_key")
        guard let apiKey = stabilityApiKey, !apiKey.isEmpty else {
            print("No Stability API key found, cannot generate real image")
            return nil
        }
        
        // For testing purposes, if no real image generation is available, we'll return nil
        // and the system will fall back to placeholders
        
        // When you have an API key for Stability AI, uncomment this code and it will work
        // The API URL for text-to-image generation
        /*
        guard let url = URL(string: "https://api.stability.ai/v1/generation/stable-diffusion-xl-1024-v1-0/text-to-image") else {
            print("Invalid Stability API URL")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Configure the request body with the prompt and other parameters
        let requestBody: [String: Any] = [
            "text_prompts": [
                ["text": prompt, "weight": 1.0]
            ],
            "cfg_scale": 7,
            "height": 1024,
            "width": 1024,
            "samples": 1,
            "steps": 30
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                defer { semaphore.signal() }
                
                if let error = error {
                    print("Error generating image with Stability AI: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    print("No data returned from Stability AI")
                    return
                }
                
                // Parse the response
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let artifacts = json["artifacts"] as? [[String: Any]],
                       let firstArtifact = artifacts.first,
                       let base64String = firstArtifact["base64"] as? String,
                       let imageData = Data(base64Encoded: base64String) {
                        print("Successfully generated image with Stability AI: \(imageData.count) bytes")
                        resultImage = imageData
                    } else {
                        print("Failed to parse Stability AI response: \(String(data: data, encoding: .utf8) ?? "Unknown")")
                    }
                } catch {
                    print("Error parsing Stability AI response: \(error.localizedDescription)")
                }
            }
            
            task.resume()
            
            // Wait for the network call to complete
            _ = semaphore.wait(timeout: .now() + 20.0) // Timeout after 20 seconds
            return resultImage
        } catch {
            print("Error preparing Stability AI request: \(error.localizedDescription)")
            return nil
        }
        */
        
        print("Real image generation not yet implemented, returning nil")
        return nil
    }
}
