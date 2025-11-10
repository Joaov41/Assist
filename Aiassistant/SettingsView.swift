import SwiftUI
import Carbon.HIToolbox
import KeyboardShortcuts // Ensure this package is included

// Ensure KeyboardShortcuts.Name extension is defined if needed, or remove if not used
/*
extension KeyboardShortcuts.Name {
    static let showPopup = Self("showPopup")
}
*/

struct SettingsView: View {
    @ObservedObject var appState: AppState
    // @State private var shortcutText = UserDefaults.standard.string(forKey: "shortcut") ?? "⌥ Space" // Shortcut display might be handled differently now
    @State private var selectedProvider: String
    @AppStorage("theme_style") private var themeStyle: String = "standard"
    @AppStorage("glass_variant") private var glassVariant: Int = 11

    // Ensure GeminiModel and OpenAIConfig are defined elsewhere
    // Ensure AppState is accessible

    init(appState: AppState, showOnlyApiSetup: Bool = false) {
        self._appState = ObservedObject(wrappedValue: appState)
        self._selectedProvider = State(initialValue: appState.currentProvider)
        self.showOnlyApiSetup = showOnlyApiSetup
        // Load initial values directly from AppSettings singleton
        self._geminiApiKey = State(initialValue: AppSettings.shared.geminiApiKey)
        self._selectedGeminiModel = State(initialValue: AppSettings.shared.geminiModel)
        self._openAIApiKey = State(initialValue: AppSettings.shared.openAIApiKey)
        self._openAIBaseURL = State(initialValue: AppSettings.shared.openAIBaseURL)
        self._openAIOrganization = State(initialValue: AppSettings.shared.openAIOrganization ?? "")
        self._openAIProject = State(initialValue: AppSettings.shared.openAIProject ?? "")
        self._openAIModelName = State(initialValue: AppSettings.shared.openAIModel)

    }

    // Gemini settings
    @State private var geminiApiKey: String
    @State private var selectedGeminiModel: GeminiModel

    // OpenAI settings
    @State private var openAIApiKey: String
    @State private var openAIBaseURL: String
    @State private var openAIOrganization: String
    @State private var openAIProject: String
    @State private var openAIModelName: String

    // @State private var displayShortcut = "" // Maybe not needed if using double-tap shift

    let showOnlyApiSetup: Bool

    // Helper View for Link Text
    struct LinkText: View {
        var body: some View {
            HStack { // Use HStack for better layout potential
                 Text("For local LLMs (e.g., Ollama), set Base URL to")
                 Text("http://localhost:11434/v1") // Common Ollama URL
                     .font(.caption.monospaced())
                     .foregroundColor(.blue.opacity(0.8))
                     .onTapGesture {
                         // Optional: Copy URL to pasteboard
                         NSPasteboard.general.clearContents()
                         NSPasteboard.general.setString("http://localhost:11434/v1", forType: .string)
                     }
                 Text("and use the model name.")
            }
             .font(.caption)
             .foregroundColor(.white.opacity(0.6))
             .fontWeight(.medium)

        }
    }

    var body: some View {
        ZStack {
            // Background - exact same as PopupView
            Group {
                if themeStyle == "glass" {
                    LiquidGlassBackground(
                        variant: GlassVariant(rawValue: glassVariant) ?? .v11,
                        cornerRadius: 0
                    ) {
                        Color.clear
                    }
                    .ignoresSafeArea()
                } else {
                    ZStack {
                        // Add a blur layer first
                        Color.black
                            .opacity(0.4)
                            .blur(radius: 20)
                            .ignoresSafeArea()
                        
                        Color(.windowBackgroundColor)
                            .opacity(1.0) // Full opacity for settings
                            .ignoresSafeArea()
                            .blur(radius: 1) // Slight blur on the background
                        
                        // Subtle gradient background
                        LinearGradient(
                            colors: [
                                Color.purple.opacity(0.08), // Even more visible gradient
                                Color.blue.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .ignoresSafeArea()
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 20) {
            if !showOnlyApiSetup {
                // Shortcut section (Updated for double-tap shift)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Keyboard Shortcut")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white.opacity(0.9))

                    Text("Activation: Double-tap Left Shift key quickly.")
                        .foregroundColor(.white.opacity(0.7))
                        .fontWeight(.medium)
                    // Remove the old KeyboardShortcuts.Recorder if not used
                    // KeyboardShortcuts.Recorder("Legacy Shortcut:", name: .showPopup)
                }

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Appearance")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white.opacity(0.9))
                    
                    Text("Theme")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white.opacity(0.9))
                    
                    Picker("Theme", selection: $themeStyle) {
                        Text("Standard").tag("standard")
                        Text("Gradient").tag("gradient")
                        Text("Glass").tag("glass")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .background(Color.black.opacity(0.15)
                        .overlay(.ultraThinMaterial.opacity(0.7))
                        .overlay(Color.black.opacity(0.05)))
                    .cornerRadius(8)
                    
                    Text("Glass theme provides a modern translucent effect")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .fontWeight(.medium)
                    
                    if themeStyle == "glass" {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Glass Variant")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.top, 10)
                            
                            HStack {
                                Text("Style:")
                                    .fontWeight(.medium)
                                    .foregroundColor(.white.opacity(0.8))
                                Slider(value: Binding(
                                    get: { Double(glassVariant) },
                                    set: { glassVariant = Int($0) }
                                ), in: 0...19, step: 1)
                                Text("\(glassVariant)")
                                    .frame(width: 30)
                                    .monospacedDigit()
                                    .fontWeight(.medium)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            
                            Text("Experiment with different glass variants (0-19)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                                .fontWeight(.medium)
                        }
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text("AI Provider")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white.opacity(0.9))
                    
                    Picker("Provider", selection: $selectedProvider) {
                        Text("Gemini AI").tag("gemini")
                        Text("OpenAI / Local LLM").tag("openai")
                    }
                    .pickerStyle(.segmented) // Use segmented style for better look
                    .background(Color.black.opacity(0.15)
                        .overlay(.ultraThinMaterial.opacity(0.7))
                        .overlay(Color.black.opacity(0.05)))
                    .cornerRadius(8)
                    .onChange(of: selectedProvider) { _, newValue in
                        // Save immediately when changed via AppSettings
                        AppSettings.shared.currentProvider = newValue
                        // AppState might need to be explicitly told to update its internal provider instance if needed
                        // Or better, AppState could observe AppSettings.shared.currentProvider
                        appState.setCurrentProvider(newValue) // Ensure this updates AppState correctly
                    }
                }
            } else {
                 Text("Configure Your AI Provider")
                     .font(.title)
                     .fontWeight(.bold)
                     .foregroundColor(.white.opacity(0.9))
                     .padding(.bottom)
                 // Default to OpenAI/Local if no keys exist? Or based on last selection?
                 // Picker("Provider", selection: $selectedProvider) { ... } // Optionally show picker here too
            }

            // Conditional Settings Views
            if selectedProvider == "gemini" {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Gemini AI Settings")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white.opacity(0.9))
                    
                    HStack {
                         TextField("API Key", text: $geminiApiKey)
                             .textFieldStyle(PlainTextFieldStyle())
                             .padding(10)
                             .background(Color.black.opacity(0.15)
                                 .overlay(.ultraThinMaterial.opacity(0.7))
                                 .overlay(Color.black.opacity(0.05)))
                             .cornerRadius(8)
                             .foregroundColor(.white.opacity(0.9))
                         Button("Get API Key") {
                             NSWorkspace.shared.open(URL(string: "https://aistudio.google.com/app/apikey")!)
                         }
                         .glassButtonStyle(variant: .v8)
                    }

                    Picker("Model", selection: $selectedGeminiModel) {
                        ForEach(GeminiModel.allCases, id: \.self) { model in
                            Text(model.displayName).tag(model)
                        }
                    }
                    .padding(.top, 5) // Add some spacing
                    .background(Color.black.opacity(0.15)
                        .overlay(.ultraThinMaterial.opacity(0.7))
                        .overlay(Color.black.opacity(0.05)))
                    .cornerRadius(8)

                }
            } else { // openai or local
                VStack(alignment: .leading, spacing: 12) {
                    Text("OpenAI / Local LLM Settings")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white.opacity(0.9))
                    
                    HStack {
                         TextField("API Key (Optional for Local)", text: $openAIApiKey)
                             .textFieldStyle(PlainTextFieldStyle())
                             .padding(10)
                             .background(Color.black.opacity(0.15)
                                 .overlay(.ultraThinMaterial.opacity(0.7))
                                 .overlay(Color.black.opacity(0.05)))
                             .cornerRadius(8)
                             .foregroundColor(.white.opacity(0.9))
                         Button("Get OpenAI Key") {
                             NSWorkspace.shared.open(URL(string: "https://platform.openai.com/account/api-keys")!)
                         }
                         .glassButtonStyle(variant: .v8)
                    }

                    TextField("Base URL (e.g., OpenAI or Local)", text: $openAIBaseURL)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(10)
                        .background(Color.black.opacity(0.15)
                            .overlay(.ultraThinMaterial.opacity(0.7))
                            .overlay(Color.black.opacity(0.05)))
                        .cornerRadius(8)
                        .foregroundColor(.white.opacity(0.9))

                    TextField("Model Name (e.g., gpt-4o, llama3)", text: $openAIModelName)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(10)
                        .background(Color.black.opacity(0.15)
                            .overlay(.ultraThinMaterial.opacity(0.7))
                            .overlay(Color.black.opacity(0.05)))
                        .cornerRadius(8)
                        .foregroundColor(.white.opacity(0.9))

                    Text("Common OpenAI models: gpt-4o, gpt-4-turbo, gpt-3.5-turbo")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .fontWeight(.medium)

                    LinkText() // Show local LLM info

                    TextField("Organization ID (Optional, OpenAI)", text: $openAIOrganization)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(10)
                        .background(Color.black.opacity(0.15)
                            .overlay(.ultraThinMaterial.opacity(0.7))
                            .overlay(Color.black.opacity(0.05)))
                        .cornerRadius(8)
                        .foregroundColor(.white.opacity(0.9))

                    TextField("Project ID (Optional, OpenAI)", text: $openAIProject)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(10)
                        .background(Color.black.opacity(0.15)
                            .overlay(.ultraThinMaterial.opacity(0.7))
                            .overlay(Color.black.opacity(0.05)))
                        .cornerRadius(8)
                        .foregroundColor(.white.opacity(0.9))

                }
            }

            Spacer() // Push save button to bottom

            HStack {
                 Spacer() // Push button right
                 Button(showOnlyApiSetup ? "Complete Setup" : "Save & Close") {
                     saveSettings()
                 }
                 .glassButtonStyle(variant: .v8)
                 .scaleEffect(1.1)
            }

        }
        .padding()
        .background(Color.black.opacity(0.1)) // Add subtle background to content
        .frame(minWidth: 500, idealWidth: 550) // Set min width
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
        .preferredColorScheme(.dark)
    }

    private func saveSettings() {
        // Save settings using the AppSettings singleton
        let settings = AppSettings.shared

        // Save Gemini settings if they were potentially edited
        settings.geminiApiKey = geminiApiKey
        settings.geminiModel = selectedGeminiModel

        // Save OpenAI/Local settings if they were potentially edited
        settings.openAIApiKey = openAIApiKey
        settings.openAIBaseURL = openAIBaseURL.isEmpty ? OpenAIConfig.defaultBaseURL : openAIBaseURL // Use default if empty
        settings.openAIModel = openAIModelName.isEmpty ? OpenAIConfig.defaultModel : openAIModelName // Use default if empty
        settings.openAIOrganization = openAIOrganization.isEmpty ? nil : openAIOrganization // Store nil if empty
        settings.openAIProject = openAIProject.isEmpty ? nil : openAIProject // Store nil if empty

        // Current provider is already saved via onChange

        // Update AppState internal configurations
        // This ensures the providers have the latest config immediately
        appState.saveGeminiConfig(apiKey: settings.geminiApiKey, model: settings.geminiModel)
        appState.saveOpenAIConfig(
            apiKey: settings.openAIApiKey,
            baseURL: settings.openAIBaseURL,
            organization: settings.openAIOrganization,
            project: settings.openAIProject,
            model: settings.openAIModel
        )

        // Close windows safely
        DispatchQueue.main.async {
            if self.showOnlyApiSetup {
                // Onboarding complete: Mark as done and close *all* setup windows
                AppSettings.shared.hasCompletedOnboarding = true // Mark onboarding as done
                print("Onboarding setup complete. Closing setup windows.")
                // **CORRECTED CALL:** Use the correct method name
                WindowManager.shared.cleanupAllWindows() // Close all managed windows
            } else {
                // Just close the settings window itself
                print("Settings saved. Closing settings window.")
                // Find the window hosting this specific view instance and close it
                // This is safer than relying on first window matching type
                 if let window = NSApp.windows.first(where: { $0.contentView is NSHostingView<SettingsView> && ($0.contentView as? NSHostingView<SettingsView>)?.rootView.appState === self.appState }) {
                     window.close() // This will trigger WindowManager's delegate
                 } else {
                      // Fallback if specific window not found easily
                      print("Could not find specific settings window to close.")
                 }
            }
        }
    }
}

