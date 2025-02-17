import Foundation

protocol AIProvider: ObservableObject {
    var isProcessing: Bool { get set }
    func processText(systemPrompt: String?, userPrompt: String, images: [Data], videos: [Data]?) async throws -> String
    func cancel()
}
