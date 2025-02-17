# AIassistant

A  macOS application that brings AI assistance leveraging both Gemini and OpenAI models.

## Key Features

- Instant UI with double-shift activation
- Support for both Gemini and OpenAI models
- Modern SwiftUI interface
- Secure API key storage
- Context-aware assistance

## Getting Started

### Prerequisites

- API key from either Google's Gemini or OpenAI
- Basic knowledge of building Xcode projects

### Building from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/aiassistant.git
   ```
2. Open `AIassistant.xcodeproj` in Xcode
3. Configure signing:
   - In Xcode, select the project in the navigator
   - Select the AIassistant target
   - Under Signing & Capabilities, choose your team
   - Update the bundle identifier if needed
4. Build and run (⌘R)

## Usage

1. After building, launch AIassistant
2. Complete the initial setup and API configuration
3. Access the assistant by double-pressing the shift key
     

### 

Components:
- A regular chat interface with support for text, html, URL, images and audio. ( video is only suported by the Gemini models) 
  For URL and PDF the code will extract the content and send to the LLM.
  For URL copy the URL to the clipboard and press New Chat
  For PDF, right click and copy the pdf file and press New Chat, the app will handle the rest
  For images and videos the same, right click and copy the pdf file and press New Chat, the app will handle the rest

![CleanShot 2025-02-17 at 19 37 41@2x](https://github.com/user-attachments/assets/6c9e9dc5-3943-41cc-81e8-bb9a581cc8e6)


  Check example videos



  
- An inline replacement on the source app ( Rewrite in 
In this mode, select the content on and external app, prompt the LLM, and the result will be inline replaced on the external app.
![CleanShot 2025-02-17 at 19 34 52@2x](https://github.com/user-attachments/assets/9ec4a427-d4c2-415f-b021-0f33942195b0)

