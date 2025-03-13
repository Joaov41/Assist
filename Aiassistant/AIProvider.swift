import Foundation

struct AIResponse {
    let text: String
    let images: [Data]
    
    init(text: String, images: [Data] = []) {
        self.text = text
        self.images = images
    }
}

protocol AIProvider: ObservableObject {
    var isProcessing: Bool { get set }
    func processText(systemPrompt: String?, userPrompt: String, images: [Data], videos: [Data]?) async throws -> AIResponse
    func cancel()
}
