# AIassistant

A powerful native macOS application that brings AI assistance directly to your desktop with seamless integration into your workflow. AIassistant leverages both Google Gemini and OpenAI's GPT models to provide intelligent, context-aware assistance across all your applications.

#Key Features

-  Instant Access - Double-tap right Shift key to activate from anywhere
-  Full Chat Interface - Rich conversations with support for text, images, videos, PDFs, and URLs
- Rewrite in Place - Transform text directly in any application without copy-paste
- Quick Actions - One-click operations like Summarize, Translate, Simplify, and more
- Image Generation - Create and modify images with Gemini's AI capabilities
- Screenshot Capture - Analyze any application window with AI
- Multi-Model Support - Switch between Gemini and OpenAI models dynamically
- Glass UI
- Secure - API keys stored securely in macOS Keychain
- Accessibility-First - Full keyboard support and system-wide automation

![CleanShot 2025-11-10 at 17 17 48@2x](https://github.com/user-attachments/assets/2bee115f-02dc-4db9-b882-5b628b0446f6)

![CleanShot 2025-11-10 at 17 17 22@2x](https://github.com/user-attachments/assets/23022a80-b944-4deb-aa75-58dd912ae08f)

![CleanShot 2025-11-10 at 17 17 01@2x](https://github.com/user-attachments/assets/f563811d-5317-4238-a3aa-efbc0dc8d99d)
![CleanShot 2025-11-10 at 17 51 20@2x](https://github.com/user-attachments/assets/d6e0c54d-acb6-4888-906e-e77956d86e2f)

## Requirements

- macOS 12.0 or later
- API key from either:
  - [Google AI Studio](https://aistudio.google.com/) (for Gemini models)
  - [OpenAI](https://platform.openai.com/) (for GPT models)
  - Or both for maximum flexibility

## Installation

### Building from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/Joaov41/Assist.git
   cd Assist
   ```

2. Open `Aiassistant.xcodeproj` in Xcode

3. Configure code signing:
   - Select the project in the navigator
   - Select the Aiassistant target
   - Under Signing & Capabilities, choose your team
   - Update the bundle identifier if needed

4. Build and run (⌘R)

5. Grant necessary permissions when prompted:
   - Accessibility (required for Rewrite in Place)
   - Screen Recording (required for Screenshot Capture)

## Usage

### First Launch

1. Launch AIassistant
2. Complete the onboarding setup
3. Enter your API keys for Gemini and/or OpenAI
4. Configure your preferred default model
5. You're ready to go!

### Activation Methods

**Keyboard Shortcut (Primary)**
- Double-tap the **right Shift key** to activate the chat popup from anywhere

**Menu Bar**
- Click the AIassistant icon in your menu bar for quick access

**Drag & Drop**
- Drag files, URLs, images, videos, or PDFs directly into the chat interface
- The app automatically detects content type and processes accordingly

---

## Core Features

### 1. Chat Interface

The full-featured chat interface supports multiple content types and provides rich, formatted responses.

#### Supported Input Types:

**Text**
- Simply type your question or prompt
- Markdown rendering for beautiful formatted responses

**URLs**
- Drag and drop a URL from your browser address bar into the chat interface
- The app automatically extracts and processes the web content


**Text Files**
- Drag and drop any text file (.txt, .md, etc.) into the chat interface
- The app reads and processes the file content automatically

**PDFs**
- Drag and drop a PDF file from Finder into the chat interface
- The app extracts the text content automatically
- Great for analyzing documents, papers, and reports

**Images**
- Drag and drop image files (.png, .jpg, .gif, etc.) into the chat interface
- Ask questions about the image or request analysis
- Works with screenshots, photos, diagrams, and more

**Videos** (Gemini models only)
- Drag and drop video files into the chat interface
- The AI can analyze and describe video content
- Supports common video formats

**Screenshot Capture**
1. In the chat interface, select a screenshot option
2. Choose an application window to capture
3. The screenshot is automatically sent to the AI for analysis

### 2. Rewrite in Place

The most powerful feature - transform text in ANY application without copy-paste!

#### How It Works:

1. **Select text** in any application (Notes, Mail, Messages, web browser, etc.)
2. **Activate AIassistant** (double-tap right Shift)
3. **Enter your transformation prompt** (e.g., "Make this more professional", "Fix grammar", "Translate to Spanish")
4. **Press Enter** or click Submit
5. **Watch the magic** - The AI-generated text automatically replaces your original selection in the source application

#### Behind the Scenes:
- AIassistant uses macOS Accessibility APIs to detect your text selection
- Sends the selected text + your prompt to the AI model
- Receives the AI response
- Automatically pastes the result back into the original application
- Uses keyboard automation to seamlessly replace the selection

#### Example Use Cases:
- **Email Writing**: "Make this email more professional"
- **Grammar Correction**: "Fix all grammar and spelling errors"
- **Translation**: "Translate this to French"
- **Tone Adjustment**: "Rewrite this in a friendly tone"
- **Simplification**: "Explain this like I'm 5"
- **Expansion**: "Add more detail to this paragraph"

**Requirements:**
- Accessibility permissions must be granted
- Text must be selectable in the target application

### 3. Quick Actions

Pre-configured AI operations for common tasks. Access them instantly from the Quick Actions menu.

#### Built-in Quick Actions:

** Summarize**
- Condenses long text, URLs, or PDFs into key points
- Perfect for research papers, articles, and documents

** Key Points**
- Extracts main ideas as a bulleted list
- Great for meeting notes and reports

** Simplify**
- Makes complex text easier to understand
- Ideal for technical documentation or legal text

** Translate to Spanish**
- Quick translation to Spanish
- Can be customized for other languages

** Describe Image**
- AI analysis of image content
- Identifies objects, scenes, text, and context

** Describe Video** (Gemini only)
- Analyzes video content
- Describes scenes, actions, and context

#### Custom Actions 🔧

**Create your own Quick Actions!**

You can define custom actions for your specific workflows:

1. Open **Settings** in AIassistant
2. Navigate to the **Quick Actions** section
3. Click **"Add Custom Action"**
4. Configure:
   - **Name**: Display name (e.g., "Code Review")
   - **Prompt**: The AI instruction (e.g., "Review this code and suggest improvements")
   - **Icon**: Choose an emoji or icon
5. Save your custom action

**Custom Action Examples:**
- "Review this code for bugs and optimization"
- "Rewrite in a humorous tone"
- "Create a social media post from this content"
- "Extract action items and create a TODO list"
- "Generate unit tests for this function"
- "Explain this concept to a beginner"

Your custom actions appear alongside built-in actions and can be used with any selected text!

### 4. Image Generation 

**Available with Gemini models only**

Create and modify images using AI:

1. In the chat interface, describe the image you want
2. Use prompts like:
   - "Generate an image of a sunset over mountains"
   - "Create a logo for a coffee shop"
   - "Draw a cartoon character of a friendly robot"
3. The AI generates the image and displays it in chat
4. You can refine by continuing the conversation

### 5. Screenshot Capture 

Capture and analyze any application window:

1. Click the **Screenshot** button in the chat interface
2. Choose from the list of running applications
3. The window is captured automatically
4. Ask questions about the screenshot:
   - "What's wrong with this design?"
   - "Summarize the information in this screenshot"
   - "Extract the text from this image"

**Use Cases:**
- UI/UX feedback and analysis
- Extract text from images (OCR)
- Debug visual issues
- Get design suggestions
- Analyze charts and graphs

---

## AI Models

AIassistant supports multiple AI models for different use cases:

### Google Gemini Models

**Gemini 2.5 Pro**
- Maximum capability and intelligence
- Best for complex reasoning and analysis
- Supports images, videos, and long contexts

**Gemini 2.5 Flash**
- Ultra-fast responses
- Great for quick questions and simple tasks
- More cost-effective

**Exclusive Features:**
- Image generation
- Video content analysis
- Longer context windows

### OpenAI Models

**GPT-5**
- Latest and most advanced model
- Superior reasoning and understanding

**GPT-4o**
- Optimized for performance
- Balanced speed and capability

**GPT-4o Mini**
- Fast and cost-effective
- Great for simple tasks and quick responses

### Switching Models

Change models anytime in **Settings**:
1. Open Settings (from menu bar or chat interface)
2. Select **AI Provider** (Gemini or OpenAI)
3. Choose your preferred **Model**
4. Model switches immediately for new conversations

---

## ⚙️ Settings

Access settings via the menu bar icon or chat interface.

**AI Provider Configuration**
- Choose between Gemini and OpenAI
- Enter or update API keys
- Select default model

**UI Customization**
- Choose from 19 glass morphism variants
- Adjust window opacity and blur
- Dark mode (always enabled)

**Behavior Settings**
- Enable/disable automatic content detection
- Configure keyboard shortcuts
- Adjust response streaming

**Quick Actions Management**
- View all quick actions
- Create custom actions
- Edit or delete existing actions
- Reorder action list

**About**
- App version information
- API usage statistics
- Privacy policy and terms

---

## Security & Privacy

- **API Keys**: Stored securely in macOS Keychain, never in plaintext
- **Local Processing**: Text selection and clipboard handling done locally
- **No Data Collection**: AIassistant doesn't collect or store your data
- **Secure Communication**: All API calls use HTTPS encryption
- **Permissions**: Only requests necessary system permissions
  - Accessibility: Required for Rewrite in Place
  - Screen Recording: Required for Screenshot Capture

---

## Technical Details

**Built With:**
- **Swift** - Modern, type-safe programming language
- **SwiftUI** - Declarative UI framework
- **AppKit** - Native macOS integration
- **Accessibility APIs** - System-wide automation
- **Markdown Rendering** - Beautiful formatted responses

**Architecture:**
- Native macOS application (not Electron/web-based)
- ~7,420 lines of Swift code
- 30+ source files
- Modular architecture with clean separation of concerns

**System Requirements:**
- macOS 12.0 or later
- Internet connection for AI API calls
- ~50MB disk space

---

## Tips & Best Practices

### Getting the Most from Rewrite in Place
- Be specific in your prompts ("Make formal" vs "Rewrite")
- Works in any app with selectable text
- Great for iterative refinement - rewrite multiple times
- Use with Quick Actions for common transformations

### Effective Prompting
- **Be specific**: "Summarize in 3 bullet points" vs "Summarize"
- **Provide context**: "Translate to casual Spanish" vs "Translate"
- **Iterate**: Refine results by continuing the conversation

### Model Selection
- Use **Gemini Pro** for complex analysis and long documents
- Use **Gemini Flash** or **GPT-4o Mini** for quick questions
- Use **GPT-5** or **GPT-4o** for critical reasoning tasks
- Use **Gemini** for image generation and video analysis

### Custom Actions
- Create actions for repetitive tasks
- Use clear, descriptive names
- Test prompts in chat first, then save as actions
- Organize actions by category (Writing, Coding, Translation, etc.)

---

## Contributing

Contributions are welcome! Feel free to:
- Report bugs or issues
- Suggest new features
- Submit pull requests
- Improve documentation

---

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

## Acknowledgments

- Powered by Google Gemini and OpenAI GPT models
- Built with Apple's native frameworks
- Glass morphism design inspiration from modern UI trends

---

## Support

For issues, questions, or feedback:
- Open an issue on GitHub
- Check existing documentation
- Review closed issues for solutions

---
