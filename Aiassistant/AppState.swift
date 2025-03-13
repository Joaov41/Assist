import SwiftUI
import AppKit

/// Represents the recognized content type in the clipboard.
enum ClipboardContentType {
    case url
    case pdf
    case video
    case image
    case text
    case none
}

class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var geminiProvider: GeminiProvider
    @Published var openAIProvider: OpenAIProvider
    
    @Published var customInstruction: String = ""
    
    /// The text content extracted from the clipboard or selection
    @Published var selectedText: String = ""
    
    /// The image data extracted from clipboard or selection
    @Published var selectedImages: [Data] = []
    
    /// The video data extracted from clipboard or selection
    @Published var selectedVideos: [Data] = []
    
    /// Tracks which content type was last detected on the clipboard
    @Published var lastClipboardType: ClipboardContentType = .none
    
    /// Whether the popup is currently visible
    @Published var isPopupVisible: Bool = false
    
    /// Whether the app is currently processing an AI request
    @Published var isProcessing: Bool = false
    
    /// The previously frontmost application (for returning focus, optional)
    @Published var previousApplication: NSRunningApplication?
    
    /// Any shared string content (optional usage)
    @Published var sharedContent: String? = nil
    
    // MARK: - Current Provider
    @Published private(set) var currentProvider: String
    
    var activeProvider: any AIProvider {
        currentProvider == "openai" ? openAIProvider : geminiProvider
    }
    
    func setCurrentProvider(_ provider: String) {
        currentProvider = provider
        AppSettings.shared.currentProvider = provider
        objectWillChange.send()
    }
    
    // MARK: - Initialization
    private init() {
        let asettings = AppSettings.shared
        self.currentProvider = asettings.currentProvider
        
        // Initialize Gemini
        let geminiConfig = GeminiConfig(apiKey: asettings.geminiApiKey,
                                        modelName: asettings.geminiModel.rawValue)
        self.geminiProvider = GeminiProvider(config: geminiConfig)
        
        // Initialize OpenAI
        let openAIConfig = OpenAIConfig(
            apiKey: asettings.openAIApiKey,
            baseURL: asettings.openAIBaseURL,
            organization: asettings.openAIOrganization,
            project: asettings.openAIProject,
            model: asettings.openAIModel
        )
        self.openAIProvider = OpenAIProvider(config: openAIConfig)
        
        if asettings.openAIApiKey.isEmpty && asettings.geminiApiKey.isEmpty {
            print("Warning: No API keys configured.")
        }
    }
    
    // MARK: - Gemini / OpenAI configuration updates
    func saveGeminiConfig(apiKey: String, model: GeminiModel) {
        AppSettings.shared.geminiApiKey = apiKey
        AppSettings.shared.geminiModel = model
        
        let config = GeminiConfig(apiKey: apiKey, modelName: model.rawValue)
        geminiProvider = GeminiProvider(config: config)
    }
    
    func saveOpenAIConfig(apiKey: String, baseURL: String, organization: String?, project: String?, model: String) {
        let asettings = AppSettings.shared
        asettings.openAIApiKey = apiKey
        asettings.openAIBaseURL = baseURL
        asettings.openAIOrganization = organization
        asettings.openAIProject = project
        asettings.openAIModel = model
        
        let config = OpenAIConfig(apiKey: apiKey,
                                  baseURL: baseURL,
                                  organization: organization,
                                  project: project,
                                  model: model)
        openAIProvider = OpenAIProvider(config: config)
    }
    
    // MARK: - Clipboard Checking
    /// Re-check the system clipboard for PDF, video, image, or text/URL.
    /// This also sets `lastClipboardType`, so the UI can show a short label.
    func recheckClipboard() {
        let pb = NSPasteboard.general
        
        // 1) Check if there's a valid http/https URL string
        if let possibleURLString = pb.string(forType: .string),
           let url = URL(string: possibleURLString),
           ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
            
            lastClipboardType = .url
            // Asynchronously fetch the page text
            Task {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    let extractedText = self.extractTextFromHTML(data: data)
                    
                    DispatchQueue.main.async {
                        self.selectedText = extractedText
                        self.selectedImages = []
                        self.selectedVideos = []
                    }
                } catch {
                    print("Error fetching URL: \(error)")
                }
            }
            return
        }
        
        // 2) Check for PDF
        if let pdfData = pb.readPDF() {
            lastClipboardType = .pdf
            let text = PDFHandler.extractText(from: pdfData)
            
            self.selectedText = text
            self.selectedImages = []
            self.selectedVideos = []
            return
        }
        
        // 3) Check for video
        if let videoData = pb.readVideo() {
            lastClipboardType = .video
            self.selectedText = ""
            self.selectedImages = []
            self.selectedVideos = [videoData]
            return
        }
        
        // 4) Check for images
        let supportedImageTypes: [NSPasteboard.PasteboardType] = [
            .init("public.png"),
            .init("public.jpeg"),
            .init("public.tiff"),
            .init("com.compuserve.gif"),
            .init("public.image")
        ]
        
        for type in supportedImageTypes {
            if let data = pb.data(forType: type) {
                lastClipboardType = .image
                self.selectedText = ""
                self.selectedImages = [data]
                self.selectedVideos = []
                return
            }
        }
        
        // 5) Otherwise, treat it as plain text
        if let text = pb.string(forType: .string), !text.isEmpty {
            lastClipboardType = .text
            self.selectedText = text
            self.selectedImages = []
            self.selectedVideos = []
            return
        }
        
        // If we reach here, there's nothing recognized in the clipboard
        lastClipboardType = .none
        self.selectedText = ""
        self.selectedImages = []
        self.selectedVideos = []
    }
    
    // For scraping HTML
    func processURLFromClipboard() {
        let pb = NSPasteboard.general
        guard let clipboardString = pb.string(forType: .string),
              let url = URL(string: clipboardString),
              (url.scheme == "http" || url.scheme == "https") else {
            print("No valid URL found in clipboard")
            return
        }
        
        isProcessing = true
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let extractedText = self.extractTextFromHTML(data: data)
                DispatchQueue.main.async {
                    self.selectedText = extractedText
                    self.isProcessing = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.isProcessing = false
                }
                print("Error processing URL: \(error.localizedDescription)")
            }
        }
    }
    
    /// Convert HTML data to plain text
    func extractTextFromHTML(data: Data) -> String {
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        if let attrString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
            return attrString.string
        }
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    // MARK: - Optional PDF Handler
    func handlePDFData(_ pdfData: Data) {
        let text = PDFHandler.extractText(from: pdfData)
        selectedText = text
    }
}

extension AppState {
    func captureExternalSelection() {
        // First try to get text from the accessibility API
        if let selectedText = AccessibilityHelper.copyTextFromFocusedElement() {
            self.selectedText = selectedText
            self.lastClipboardType = .text
            return
        }
        
        // Fallback to checking clipboard
        self.recheckClipboard()
    }
}
