import SwiftUI
import MarkdownUI

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: String // "user" or "assistant"
    let content: String
    let images: [Data]
    let timestamp: Date = Date()
    
    init(role: String, content: String, images: [Data] = []) {
        self.role = role
        self.content = content
        self.images = images
    }
    
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id &&
        lhs.role == rhs.role &&
        lhs.content == rhs.content &&
        lhs.timestamp == rhs.timestamp &&
        lhs.images == rhs.images
    }
}

struct ResponseView: View {
    @StateObject private var viewModel: ResponseViewModel
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("use_gradient_theme") private var useGradientTheme = false
    @State private var inputText: String = ""
    @State private var isRegenerating: Bool = false
    
    init(content: String, selectedText: String, option: WritingOption, images: [Data] = []) {
        self._viewModel = StateObject(wrappedValue: ResponseViewModel(
            content: content,
            selectedText: selectedText,
            option: option,
            images: images
        ))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top toolbar with controls
            HStack {
                Button(action: { viewModel.copyContent() }) {
                    Label(viewModel.showCopyConfirmation ? "Copied!" : "Copy",
                          systemImage: viewModel.showCopyConfirmation ? "checkmark" : "doc.on.doc")
                }
                .animation(.easeInOut, value: viewModel.showCopyConfirmation)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button(action: { viewModel.fontSize = max(10, viewModel.fontSize - 2) }) {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    .disabled(viewModel.fontSize <= 10)
                    
                    Button(action: { viewModel.fontSize = 14 }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    
                    Button(action: { viewModel.fontSize = min(24, viewModel.fontSize + 2) }) {
                        Image(systemName: "plus.magnifyingglass")
                    }
                    .disabled(viewModel.fontSize >= 24)
                }
            }
            .padding()
            .background(Color(.windowBackgroundColor))
            
            // Chat messages area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.messages) { message in
                            ChatMessageView(message: message, fontSize: viewModel.fontSize)
                                .id(message.id)
                                .frame(maxWidth: .infinity, alignment: message.role == "user" ? .trailing : .leading)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages, initial: true) { oldValue, newValue in
                    if let lastId = newValue.last?.id {
                        withAnimation {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Input area
            VStack(spacing: 8) {
                Divider()
                
                HStack(spacing: 8) {
                    TextField("Ask a follow-up question...", text: $inputText)
                        .textFieldStyle(.plain)
                        .appleStyleTextField(
                            text: inputText,
                            isLoading: isRegenerating,
                            onSubmit: sendMessage
                        )
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(Color(.windowBackgroundColor))
        }
        .windowBackground(useGradient: useGradientTheme)
    }
    
    private func sendMessage() {
        guard !inputText.isEmpty else { return }
        let question = inputText
        inputText = ""
        isRegenerating = true
        viewModel.processFollowUpQuestion(question) {
            isRegenerating = false
        }
    }
}

struct ChatMessageView: View {
    
    let message: ChatMessage
    let fontSize: CGFloat
    
    var body: some View {
        // If user message is on the right, assistant on the left:
        HStack(alignment: .top, spacing: 12) {
            
            // If it's assistant, push bubble to the left
            if message.role == "assistant" {
                bubbleView(role: message.role)
                Spacer(minLength: 15)
            } else {
                Spacer(minLength: 15)
                bubbleView(role: message.role)
            }
        }
        .padding(.top, 4)
    }
    
    @ViewBuilder
    private func bubbleView(role: String) -> some View {
        VStack(alignment: role == "assistant" ? .leading : .trailing, spacing: 2) {
            VStack(alignment: role == "assistant" ? .leading : .trailing, spacing: 8) {
                // Text content
                Markdown(message.content)
                    .font(.system(size: fontSize))
                    .textSelection(.enabled)
                
                // Directly display placeholder for image generation messages
                if !message.images.isEmpty && message.content.contains("Image generated") {
                    Text("🖼️ View generated image in the popup window")
                        .font(.system(size: fontSize, weight: .medium))
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
                
                // Images if any
                ForEach(0..<message.images.count, id: \.self) { index in
                    let imageData = message.images[index]
                    
                    VStack(spacing: 10) {
                        Text("📸 Generated Image")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .padding(.top, 5)
                        
                        Group {
                            if let nsImage = NSImage(data: imageData) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: 500, maxHeight: 500)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                    .shadow(radius: 2)
                                    .background(Color.white.opacity(0.05))
                                    .colorScheme(.light)
                            } else {
                                // Fallback text if image can't be displayed
                                Text("Image data could not be displayed (Size: \(imageData.count) bytes)")
                                    .foregroundColor(.red)
                                    .padding()
                                    .frame(width: 400, height: 200)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        Text("Size: \(ByteCountFormatter.string(fromByteCount: Int64(imageData.count), countStyle: .file))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 12)
                    .background(Color(.textBackgroundColor).opacity(0.15))
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
            }
            .chatBubbleStyle(isFromUser: message.role == "user")
            
            // Time stamp
            Text(message.timestamp.formatted(.dateTime.hour().minute()))
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.bottom, 2)
        }
        .frame(maxWidth: 500, alignment: role == "assistant" ? .leading : .trailing)
    }
}

extension View {
    func maxWidth(_ width: CGFloat) -> some View {
        frame(maxWidth: width)
    }
}

// Update ResponseViewModel to handle chat messages
final class ResponseViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var fontSize: CGFloat = 14
    @Published var showCopyConfirmation: Bool = false
    
    let selectedText: String
    let option: WritingOption
    
    init(content: String, selectedText: String, option: WritingOption, images: [Data] = []) {
        self.selectedText = selectedText
        self.option = option
        
        // Initialize with the first message
        self.messages.append(ChatMessage(
            role: "assistant",
            content: content,
            images: images
        ))
    }
    
    func processFollowUpQuestion(_ question: String, completion: @escaping () -> Void) {
        // Add user message
        DispatchQueue.main.async {
            self.messages.append(ChatMessage(
                role: "user",
                content: question
            ))
        }
        
        Task {
            do {
                // Build conversation history
                let conversationHistory = messages.map { message in
                    return "\(message.role == "user" ? "User" : "Assistant"): \(message.content)"
                }.joined(separator: "\n\n")
                
                // Create prompt with context
                let contextualPrompt = """
                Previous conversation:
                \(conversationHistory)
                
                User's new question: \(question)
                
                Respond to the user's question while maintaining context from the previous conversation.
                """
                
                let response = try await AppState.shared.activeProvider.processText(
                    systemPrompt: """
                    You are a writing and coding assistant. Your sole task is to respond to the user's instruction thoughtfully and comprehensively.
                    If the instruction is a question, provide a detailed answer. But always return the best and most accurate answer and not different options. 
                    If it's a request for help, provide clear guidance and examples where appropriate. Make sure to use the language used or specified by the user instruction.
                    Use Markdown formatting to make your response more readable.
                    """,
                    userPrompt: contextualPrompt,
                    images: AppState.shared.selectedImages,
                    videos: AppState.shared.selectedVideos
                )
                
                DispatchQueue.main.async {
                    self.messages.append(ChatMessage(
                        role: "assistant",
                        content: response.text,
                        images: response.images
                    ))
                    completion()
                }
            } catch {
                #if DEBUG
                print("Error processing follow-up: \(error)")
                #endif
                completion()
            }
        }
    }
    
    func clearConversation() {
        messages.removeAll()
    }
    
    func copyContent() {
        // Concatenate all messages in the conversation
        let conversationText = messages.map { message in
            return "\(message.role.capitalized): \(message.content)" // Format each message with role
        }.joined(separator: "\n\n") // Join messages with double newlines for readability

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(conversationText, forType: .string)

        showCopyConfirmation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.showCopyConfirmation = false
        }
    }
}
