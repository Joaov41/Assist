import SwiftUI
import Cocoa  // For CGEvent and related APIs
import MarkdownUI  // Add this import

struct PopupView: View {
    @ObservedObject var appState: AppState
    @AppStorage("theme_style") private var themeStyle: String = "standard"
    
    // Local chat state for the conversation
    @State private var chatMessages: [String] = []
    @State private var userInput: String = ""
    
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
                    ForEach(chatMessages, id: \.self) { msg in
                        if msg.hasPrefix("User: ") {
                            Text(msg)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(messageBackground)
                                .cornerRadius(12)
                        } else if msg.hasPrefix("Assistant: ") {
                            let response = msg.replacingOccurrences(of: "Assistant: ", with: "")
                            Markdown(response)
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
            chatMessages.append("User attached a PDF.")
        case .url:
            chatMessages.append("User attached a URL.")
        case .image:
            chatMessages.append("User attached an Image.")
        case .video:
            chatMessages.append("User attached a Video.")
        case .text:
            chatMessages.append("User attached some Text.")
        case .none:
            break
        }
    }
    
    /// Regular chat: combines any extracted text with the user's typed message.
    private func sendChatMessage() {
        guard !userInput.isEmpty else { return }
        let typedPrompt = userInput
        userInput = ""
        chatMessages.append("User: \(typedPrompt)")
        
        let combinedPrompt = """
        \(appState.selectedText)
        
        User says: \(typedPrompt)
        """
        
        isProcessing = true
        Task {
            do {
                let response = try await appState.activeProvider.processText(
                    systemPrompt: nil,
                    userPrompt: combinedPrompt,
                    images: appState.selectedImages,
                    videos: appState.selectedVideos
                )
                chatMessages.append("Assistant: \(response)")
            } catch {
                chatMessages.append("Error: \(error.localizedDescription)")
            }
            isProcessing = false
        }
    }
    
    /// Clears the chat and rechecks the clipboard.
    private func startNewChat() {
        chatMessages.removeAll()
        userInput = ""
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
        
        print("Target app for text operation: \(targetApp.localizedName ?? "Unknown") (\(targetApp.bundleIdentifier ?? "unknown bundle id"))")
        
        Task {
            // Step 1: Activate target app and copy text
            DispatchQueue.main.async {
                targetApp.activate(options: .activateIgnoringOtherApps)
            }
            // Wait for activation
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            
            guard let externalText = AccessibilityHelper.copyTextFromFocusedElement(),
                  !externalText.isEmpty else {
                print("No text available from the external app's selection.")
                isProcessing = false
                return
            }
            
            print("Successfully captured text of length: \(externalText.count)")
            print("Captured text preview: \(String(externalText.prefix(50)))...")
            
            // Step 2: Build the prompt
            let instructions = userInput
            userInput = "" // Clear input after capturing instructions
            let prompt = """
            Follow instructions of the user (return only the rewritten text, no disclaimers).

            Instructions: \(instructions)

            Original Text:
            \(externalText)
            """
            
            do {
                // Step 3: Send the prompt to the LLM
                let response = try await appState.activeProvider.processText(
                    systemPrompt: nil,
                    userPrompt: prompt,
                    images: appState.selectedImages,
                    videos: appState.selectedVideos
                )
                
                // Step 4: Paste the rewritten text back
                DispatchQueue.main.async {
                    // Make sure target app is still available
                    if targetApp.isTerminated {
                        print("Target application was closed. Copying result to clipboard instead.")
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(response, forType: .string)
                    } else {
                        AccessibilityHelper.replaceTextInFocusedElement(with: response)
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
        let conversationText = chatMessages.map { message in
            message // Each message already includes the role prefix
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
}

