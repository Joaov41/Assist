import SwiftUI
import Cocoa  // For CGEvent and related APIs
import MarkdownUI  // Add this import

struct PopupView: View {
    @ObservedObject var appState: AppState
    @AppStorage("theme_style") private var themeStyle: String = "standard"
    
    // Local chat state for the conversation with unique IDs and image support
    @State private var chatMessages: [(id: UUID, message: String, images: [Data])] = []
    @State private var userInput: String = ""
    
    // Track the most recently generated image for editing requests
    @State private var lastGeneratedImage: Data? = nil
    
    // Track whether we are calling the AI
    @State private var isProcessing = false
    
    // Store the application that was active when our popup appeared
    @State private var targetApplication: NSRunningApplication?
    
    // Define interaction modes: Chat vs. Rewrite in Place
    enum InteractionMode: String, CaseIterable {
        case chat = "Chat"
        case rewrite = "Rewrite in Place"
    }
    
    @State private var selectedMode: InteractionMode = .chat
    
    var messageBackground: some View {
        Color.clear.overlay(.ultraThinMaterial.opacity(0.3))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Chat messages scroll area
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(chatMessages, id: \.id) { item in
                        let msg = item.message
                        if msg.hasPrefix("User: ") {
                            Text(msg)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(messageBackground)
                                .cornerRadius(12)
                        } else if msg.hasPrefix("Assistant: ") {
                            let response = msg.replacingOccurrences(of: "Assistant: ", with: "")
                            VStack(alignment: .leading, spacing: 8) {
                                // Text content
                                Markdown(response)
                                    .padding(.bottom, !item.images.isEmpty ? 8 : 0)
                                
                                // Display images if present
                                if !item.images.isEmpty {
                                    ForEach(0..<item.images.count, id: \.self) { index in
                                        let imageData = item.images[index]
                                        VStack(spacing: 8) {
                                            if let nsImage = NSImage(data: imageData) {
                                                ZStack(alignment: .topTrailing) {
                                                    Image(nsImage: nsImage)
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fit)
                                                        .frame(maxWidth: 300, maxHeight: 300)
                                                        .cornerRadius(8)
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 8)
                                                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                                        )
                                                        .shadow(radius: 2)
                                                    
                                                    Button(action: {
                                                        saveImage(imageData)
                                                    }) {
                                                        Image(systemName: "square.and.arrow.down")
                                                            .foregroundColor(.white)
                                                            .padding(8)
                                                            .background(Color.black.opacity(0.7))
                                                            .clipShape(Circle())
                                                    }
                                                    .buttonStyle(PlainButtonStyle())
                                                    .padding(8)
                                                    .scaleEffect(1.2)
                                                }
                                            } else {
                                                Text("Image could not be displayed")
                                                    .foregroundColor(.red)
                                                    .padding()
                                                    .frame(maxWidth: .infinity)
                                                    .background(Color.gray.opacity(0.1))
                                                    .cornerRadius(8)
                                            }
                                            
                                            Text("Generated Image")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            
                                            Button("Save Image") {
                                                saveImage(imageData)
                                            }
                                            .font(.caption)
                                            .padding(.vertical, 4)
                                            .padding(.horizontal, 10)
                                            .background(Color.blue.opacity(0.2))
                                            .cornerRadius(8)
                                            
                                            if item.id == chatMessages.last?.id && item.images.contains(where: { $0 == lastGeneratedImage }) {
                                                Text("Tip: You can request changes to this image")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                                    .padding(.top, 2)
                                                
                                                Button("Modify This Image") {
                                                    userInput = "Create a new version of this image but with: "
                                                    // Focus the text input
                                                    NSApp.keyWindow?.makeFirstResponder(nil)
                                                }
                                                .font(.caption)
                                                .padding(.vertical, 4)
                                                .padding(.horizontal, 10)
                                                .background(Color.purple.opacity(0.2))
                                                .cornerRadius(8)
                                                .padding(.top, 4)
                                                .help("Gemini will create a new image based on the current one with your requested changes")
                                            }
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(messageBackground)
                            .cornerRadius(12)
                        } else {
                            Text(msg)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(messageBackground)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Bottom section with controls
            VStack(spacing: 0) {
                Divider()
                    .background(.secondary)
                
                // Mode Picker: Chat vs. Rewrite in Place
                HStack {
                    Picker("", selection: $selectedMode) {
                        ForEach(InteractionMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                // Instructions for Rewrite mode
                if selectedMode == .rewrite {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("How to use Rewrite:")
                            .fontWeight(.medium)
                        Text("1. Select text in any application")
                        Text("2. Type rewrite instructions below")
                        Text("3. Press Send to replace the text")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
                }
                
                // Input area with modern styling
                HStack(spacing: 12) {
                    TextField(selectedMode == .rewrite ? "Type rewrite instructions..." : "Type your message...", 
                             text: $userInput)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                        .onSubmit { onSend() }
                        .disabled(isProcessing)
                    
                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.8)
                    }
                    
                    Button(action: onSend) {
                        Text(selectedMode == .rewrite ? "Rewrite" : "Send")
                            .fontWeight(.medium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isProcessing || userInput.isEmpty)
                }
                .padding()
                
            // Bottom row: New Chat button with modern styling
            HStack {
                Button(action: startNewChat) {
                    Label("New Chat", systemImage: "plus.message")
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.leading, 12)
                
                Spacer()
                
                Button(action: exportChat) {
                    Label("Export", systemImage: "square.and.arrow.up")
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.trailing, 12)
            }
                .padding(.bottom, 8)
            }
        }
        .background(
            ZStack {
                Color(.windowBackgroundColor)
                    .opacity(0.95)
                    .ignoresSafeArea()
                
                // Subtle gradient background
                LinearGradient(
                    colors: [
                        Color.purple.opacity(0.02),
                        Color.blue.opacity(0.02)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
        )
        .cornerRadius(12)
        .preferredColorScheme(.dark)
        .onAppear {
            setupApplicationTracking()
        }
    }
    
    private func setupApplicationTracking() {
        // Store initial target application
        if let currentApp = NSWorkspace.shared.frontmostApplication,
           currentApp.bundleIdentifier != Bundle.main.bundleIdentifier {
            targetApplication = currentApp
            appState.previousApplication = currentApp
            print("Initial target application: \(currentApp.localizedName ?? "Unknown")")
        }
        
        // Set up notification observer for application switches
        NotificationCenter.default.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: NSWorkspace.shared,
            queue: .main
        ) { notification in
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
               app.bundleIdentifier != Bundle.main.bundleIdentifier {
                targetApplication = app
                appState.previousApplication = app
                print("Updated target application: \(app.localizedName ?? "Unknown")")
            }
        }
        
        populateInitialChatState()
    }
    
    // MARK: - Helper Methods
    
    /// Called when user presses Return or taps Send.
    private func onSend() {
        switch selectedMode {
        case .chat:
            sendChatMessage()
        case .rewrite:
            rewriteInPlace()
        }
    }
    
    /// Display a short label based on the detected clipboard type.
    private func populateInitialChatState() {
        switch appState.lastClipboardType {
        case .pdf:
            chatMessages.append((id: UUID(), message: "User attached a PDF.", images: []))
        case .url:
            chatMessages.append((id: UUID(), message: "User attached a URL.", images: []))
        case .image:
            chatMessages.append((id: UUID(), message: "User attached an Image.", images: []))
        case .video:
            chatMessages.append((id: UUID(), message: "User attached a Video.", images: []))
        case .text:
            chatMessages.append((id: UUID(), message: "User attached some Text.", images: []))
        case .none:
            break
        }
    }
    
    /// Regular chat: combines any extracted text with the user's typed message.
    private func sendChatMessage() {
        guard !userInput.isEmpty else { return }
        let typedPrompt = userInput
        userInput = ""
        chatMessages.append((id: UUID(), message: "User: \(typedPrompt)", images: []))
        
        // Detect if this is an image editing request
        let isImageEditRequest = detectImageEditRequest(typedPrompt)
        
        // If this is an image edit request and we have a previous image, include it
        var imagesToInclude = appState.selectedImages
        if isImageEditRequest, let lastImage = lastGeneratedImage, !appState.selectedImages.contains(lastImage) {
            print("Image edit request detected - including last generated image")
            imagesToInclude.append(lastImage)
        }
        
        let combinedPrompt = """
        \(appState.selectedText)
        
        User says: \(typedPrompt)
        """
        
        // Create system prompt for image editing
        let systemPrompt: String?
        let finalPrompt: String
        
        if isImageEditRequest && lastGeneratedImage != nil {
            systemPrompt = """
            You are an AI that can generate new images based on reference images. The user has attached an image and wants you to create a new version with specific changes.
            When you receive an image along with a request for modifications:
            1. Examine the attached image carefully
            2. Create a NEW image that incorporates the requested changes 
            3. Return the newly generated image
            
            Your strength is in generating images based on examples and descriptions.
            """
            
            finalPrompt = """
            I've attached an image and I'd like you to create a new version with these changes: \(typedPrompt)
            
            Please use the attached image as a reference and create a new image that incorporates these modifications.
            The new image should maintain the overall essence of the original but with the requested changes applied.
            """
        } else {
            systemPrompt = nil
            finalPrompt = combinedPrompt
        }
        
        isProcessing = true
        Task {
            do {
                let aiResponse = try await appState.activeProvider.processText(
                    systemPrompt: systemPrompt,
                    userPrompt: finalPrompt,
                    images: imagesToInclude,
                    videos: appState.selectedVideos
                )
                
                if !aiResponse.images.isEmpty {
                    // Store the most recent generated image for potential future edits
                    if let latestImage = aiResponse.images.last {
                        lastGeneratedImage = latestImage
                    }
                    
                    // If there are images in the response, create a response window
                    DispatchQueue.main.async {
                        // Add debug print
                        print("Creating response window with \(aiResponse.images.count) images")
                        
                        let window = ResponseWindow(
                            title: "AI Response with Images",
                            content: aiResponse.text,
                            selectedText: appState.selectedText,
                            option: WritingOption.general,
                            images: aiResponse.images
                        )
                        WindowManager.shared.addResponseWindow(window)
                        
                        // Add a message to the chat including the image data
                        self.chatMessages.append((
                            id: UUID(), 
                            message: "Assistant: \(aiResponse.text)",
                            images: aiResponse.images
                        ))
                    }
                } else if isImageEditRequest && lastGeneratedImage != nil {
                    // Handle the case where an image edit was requested but no image was returned
                    DispatchQueue.main.async {
                        print("Image edit request acknowledged but no modified image was returned")
                        
                        // Provide feedback to user about the limitation
                        let limitationMessage = """
                        I attempted to create a modified version of the image based on your request, but wasn't able to generate a new image.
                        
                        Please try asking for the modification in a different way, such as:
                        
                        "Create a version of this image with a blue background"
                        "Transform this image to have a more cartoon-like style"
                        "Make a similar image but with mountains in the background"
                        
                        This often works better with more specific, descriptive instructions.
                        """
                        
                        chatMessages.append((id: UUID(), message: "Assistant: \(limitationMessage)", images: []))
                    }
                } else {
                    // Regular text response
                    chatMessages.append((id: UUID(), message: "Assistant: \(aiResponse.text)", images: []))
                }
            } catch {
                chatMessages.append((id: UUID(), message: "Error: \(error.localizedDescription)", images: []))
            }
            isProcessing = false
        }
    }
    
    // Detect if a prompt is requesting edits to a previously generated image
    private func detectImageEditRequest(_ prompt: String) -> Bool {
        let lowerPrompt = prompt.lowercased()
        
        // Look for phrases indicating image editing
        let editingPhrases = [
            "edit this image", "modify the image", "change the image",
            "update the image", "adjust the image", "can you change the",
            "make the image", "alter the image", "transform the image",
            "update this", "edit the picture", "change the color", 
            "add to the image", "remove from the image",
            "modify this", "edit it", "change it", "update it",
            "make it more", "make it less", "make it look", "turn it into",
            "convert the image", "apply a filter", "add effect", "add a filter",
            "enhance the image", "crop the image", "resize the image",
            "rotate the image", "flip the image", "add text to the image",
            "apply sepia", "make it black and white", "add border", "add frame",
            "add a background", "remove the background", "change the background",
            "brighten", "darken", "increase contrast", "decrease contrast",
            "add saturation", "remove saturation", "make it warmer", "make it cooler",
            "add shadows", "remove shadows", "can you make", "please edit",
            "create a version", "create a new version", "new version", 
            "similar to this", "based on this", "like this one", 
            "use this image", "using this image", "from this image"
        ]
        
        return editingPhrases.contains { lowerPrompt.contains($0) } && lastGeneratedImage != nil
    }
    
    /// Clears the chat and rechecks the clipboard.
    private func startNewChat() {
        chatMessages.removeAll()
        userInput = ""
        lastGeneratedImage = nil
        appState.selectedText = ""
        appState.selectedImages = []
        appState.selectedVideos = []
        appState.lastClipboardType = .none
        appState.recheckClipboard()
        populateInitialChatState()
    }
    
    /// The inline rewrite flow
    private func rewriteInPlace() {
        guard !userInput.isEmpty else {
            print("No rewrite instructions typed.")
            return
        }
        isProcessing = true
        
        // Get the current frontmost application if available, otherwise use stored target
        let currentApp = NSWorkspace.shared.frontmostApplication
        let targetApp = currentApp?.bundleIdentifier != Bundle.main.bundleIdentifier ? currentApp : targetApplication
        
        guard let targetApp = targetApp,
              !targetApp.isTerminated else {
            print("Please select text in another application first")
            isProcessing = false
            return
        }
        
        // Make sure it's not our own app
        if targetApp.bundleIdentifier == Bundle.main.bundleIdentifier {
            print("Please select text in another application first")
            isProcessing = false
            return
        }
        
        // Update stored target application
        self.targetApplication = targetApp
        appState.previousApplication = targetApp
        
        // Check if this is a spreadsheet application
        let isSpreadsheetApp = targetApp.bundleIdentifier?.contains("excel") == true || 
                               targetApp.bundleIdentifier?.contains("numbers") == true || 
                               targetApp.bundleIdentifier?.contains("sheets") == true ||
                               targetApp.localizedName?.lowercased().contains("excel") == true ||
                               targetApp.localizedName?.lowercased().contains("numbers") == true ||
                               targetApp.localizedName?.lowercased().contains("sheets") == true
        
        print("Target app for text operation: \(targetApp.localizedName ?? "Unknown") (\(targetApp.bundleIdentifier ?? "unknown bundle id"))")
        print("Is spreadsheet app: \(isSpreadsheetApp)")
        
        // Store a reference to our app for later reactivation
        let ourApp = NSRunningApplication.current
        
        Task {
            // Step 1: Activate target app and copy text
            targetApp.activate(options: .activateIgnoringOtherApps)
            
            // Wait for activation with consistent timing
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            
            guard let externalText = AccessibilityHelper.copyTextFromFocusedElement(),
                  !externalText.isEmpty else {
                print("No text available from the external app's selection.")
                isProcessing = false
                return
            }
            
            print("Successfully captured text of length: \(externalText.count)")
            print("Captured text preview: \(String(externalText.prefix(50)))...")
            
            // Step 2: Build the prompt with special handling for spreadsheets
            let instructions = userInput
            userInput = "" // Clear input after capturing instructions
            
            // Detect if this is an image editing request
            let isImageEditRequest = detectImageEditRequest(instructions)
            
            // If this is an image edit request and we have a previous image, include it
            var imagesToInclude = appState.selectedImages
            if isImageEditRequest, let lastImage = lastGeneratedImage, !appState.selectedImages.contains(lastImage) {
                print("Image edit request detected in rewrite mode - including last generated image")
                imagesToInclude.append(lastImage)
            }
            
            // Detect if content appears to be tabular/CSV data
            let containsTabsOrCommas = externalText.contains("\t") || 
                                       (externalText.contains(",") && externalText.contains("\n"))
            let looksLikeTableData = containsTabsOrCommas || isSpreadsheetApp
            
            let formatInstructions = looksLikeTableData ? 
                "Important: Preserve the table structure exactly. Maintain all tabs, commas, and line breaks in their original positions. If this is spreadsheet data, ensure each cell's content is modified while keeping the overall format intact." : ""
            
            // Create system prompt and final prompt based on whether this is an image edit
            let systemPrompt: String?
            let finalPrompt: String
            
            if isImageEditRequest && lastGeneratedImage != nil {
                systemPrompt = """
                You are an AI that can generate new images based on reference images. The user has attached an image and wants you to create a new version with specific changes.
                When you receive an image along with a request for modifications:
                1. Examine the attached image carefully
                2. Create a NEW image that incorporates the requested changes 
                3. Return the newly generated image
                
                Your strength is in generating images based on examples and descriptions.
                """
                
                finalPrompt = """
                I've attached an image and I'd like you to create a new version with these changes: \(instructions)
                
                Please use the attached image as a reference and create a new image that incorporates these modifications.
                The new image should maintain the overall essence of the original but with the requested changes applied.
                """
            } else {
                systemPrompt = nil
                finalPrompt = """
                Follow instructions of the user (return only the rewritten text, no disclaimers).
                
                \(formatInstructions)

                Instructions: \(instructions)

                Original Text:
                \(externalText)
                """
            }
            
            do {
                // Step 3: Send the prompt to the LLM
                let aiResponse = try await appState.activeProvider.processText(
                    systemPrompt: systemPrompt,
                    userPrompt: finalPrompt,
                    images: imagesToInclude,
                    videos: appState.selectedVideos
                )
                
                // Check if there are images in the response
                if !aiResponse.images.isEmpty {
                    // Store the most recent generated image for potential future edits
                    if let latestImage = aiResponse.images.last {
                        lastGeneratedImage = latestImage
                    }
                    
                    // If there are images, display them in a ResponseWindow
                    DispatchQueue.main.async {
                        // Add debug print
                        print("Rewrite: Creating response window with \(aiResponse.images.count) images")
                        
                        let window = ResponseWindow(
                            title: "AI Generated Image",
                            content: aiResponse.text.isEmpty ? "Image successfully generated from prompt" : aiResponse.text,
                            selectedText: externalText,
                            option: WritingOption.general,
                            images: aiResponse.images
                        )
                        WindowManager.shared.addResponseWindow(window)
                        
                        // Add a message to the chat including the image data
                        self.chatMessages.append((
                            id: UUID(),
                            message: "Assistant: \(aiResponse.text.isEmpty ? "Image successfully generated" : aiResponse.text)",
                            images: aiResponse.images
                        ))
                        
                        // Reactivate our app to show the window
                        ourApp.activate(options: .activateIgnoringOtherApps)
                    }
                } else if isImageEditRequest && lastGeneratedImage != nil {
                    // Handle the case where an image edit was requested but no image was returned
                    DispatchQueue.main.async {
                        print("Rewrite: Image edit request acknowledged but no modified image was returned")
                        
                        // Provide feedback to user about the limitation
                        let limitationMessage = """
                        I attempted to create a modified version of the image based on your request, but wasn't able to generate a new image.
                        
                        Please try asking for the modification in a different way, such as:
                        
                        "Create a version of this image with a blue background"
                        "Transform this image to have a more cartoon-like style"
                        "Make a similar image but with mountains in the background"
                        
                        This often works better with more specific, descriptive instructions.
                        """
                        
                        self.chatMessages.append((
                            id: UUID(),
                            message: "Assistant: \(limitationMessage)",
                            images: []
                        ))
                        
                        // Reactivate our app to show the message
                        ourApp.activate(options: .activateIgnoringOtherApps)
                    }
                } else {
                    // Step 4: Paste the rewritten text back with special handling for spreadsheets
                    DispatchQueue.main.async {
                        // Make sure target app is still available
                        if targetApp.isTerminated {
                            print("Target application was closed. Copying result to clipboard instead.")
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(aiResponse.text, forType: .string)
                        } else {
                            // For spreadsheet apps, add a slightly longer delay before pasting
                            if isSpreadsheetApp {
                                Thread.sleep(forTimeInterval: 0.2)
                            }
                            AccessibilityHelper.replaceTextInFocusedElement(with: aiResponse.text)
                            
                            // Reactivate our app after operation completes
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                ourApp.activate(options: .activateIgnoringOtherApps)
                            }
                        }
                    }
                }
            } catch {
                print("Error rewriting: \(error.localizedDescription)")
            }
            
            isProcessing = false
        }
    }
    
    /// Exports the chat conversation to a text file
    private func exportChat() {
        // Format the conversation
        let conversationText = chatMessages.map { item in
            item.message // Each message already includes the role prefix
        }.joined(separator: "\n\n")
        
        // Create date formatter for filename
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HHmm"
        let dateString = dateFormatter.string(from: Date())
        
        // Create save panel
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.text]
        savePanel.nameFieldStringValue = "conversation-\(dateString).txt"
        savePanel.message = "Choose where to save the conversation"
        savePanel.prompt = "Export"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try conversationText.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    print("Error saving conversation: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func saveImage(_ imageData: Data) {
        guard let image = NSImage(data: imageData) else {
            print("Failed to create image from data")
            return
        }
        
        // Create save panel
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png, .jpeg]
        
        // Create date formatter for default filename
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let dateString = dateFormatter.string(from: Date())
        
        savePanel.nameFieldStringValue = "generated-image-\(dateString).png"
        savePanel.message = "Save Generated Image"
        savePanel.prompt = "Save"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    // Determine file type based on the extension
                    let isJPEG = url.pathExtension.lowercased() == "jpg" || 
                                 url.pathExtension.lowercased() == "jpeg"
                    
                    // Convert NSImage to the appropriate format
                    let imageRep = NSBitmapImageRep(data: imageData)
                    let fileData: Data?
                    
                    if isJPEG {
                        fileData = imageRep?.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
                    } else {
                        fileData = imageRep?.representation(using: .png, properties: [:])
                    }
                    
                    if let fileData = fileData {
                        try fileData.write(to: url)
                        print("Image successfully saved to \(url.path)")
                    } else {
                        print("Failed to create image representation")
                    }
                } catch {
                    print("Error saving image: \(error.localizedDescription)")
                }
            }
        }
    }
}
