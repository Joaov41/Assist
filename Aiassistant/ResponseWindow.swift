
import SwiftUI

class ResponseWindow: NSWindow {
    init(title: String, content: String, selectedText: String, option: WritingOption, images: [Data] = []) {
        // Use larger default size when there are images
        let windowSize = !images.isEmpty ? NSRect(x: 0, y: 0, width: 800, height: 700) : NSRect(x: 0, y: 0, width: 600, height: 500)
        
        super.init(
            contentRect: windowSize,
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        // Set a more descriptive title if it's an image
        if !images.isEmpty && title == "AI Response with Images" {
            self.title = "🖼️ AI Generated Image"
        } else {
            self.title = title
        }
        
        // Ensure minimum size is appropriate for images
        self.minSize = !images.isEmpty ? NSSize(width: 600, height: 500) : NSSize(width: 400, height: 300)
        self.isReleasedWhenClosed = false
        
        // Create direct image display for any window containing images
        if !images.isEmpty {
            print("Creating custom direct image window...")
            
            // Create a robust image view with native AppKit for better compatibility
            if let firstImage = images.first,
               let nsImage = NSImage(data: firstImage) {
                print("Setting image of size: \(nsImage.size.width) x \(nsImage.size.height) to window")
                
                // Adjust the image view size based on the image's dimensions
                let aspectRatio = nsImage.size.width / nsImage.size.height
                let viewHeight = min(nsImage.size.height, windowSize.height - 70) // Leave space for label
                let viewWidth = min(nsImage.size.width, viewHeight * aspectRatio)
                
                // Create image view with proper sizing
                let imageView = NSImageView(frame: NSRect(x: 0, y: 0, width: viewWidth, height: viewHeight))
                imageView.image = nsImage
                imageView.imageScaling = .scaleProportionallyUpOrDown
                imageView.imageAlignment = .alignCenter
                
                // Enable smooth image scaling
                imageView.animates = true
                imageView.allowsCutCopyPaste = true
                
                // Make image view background clear to avoid artifacts
                imageView.wantsLayer = true
                imageView.layer?.backgroundColor = NSColor.clear.cgColor
                
                // Create a scroll view with proper configuration
                let scrollView = NSScrollView(frame: NSRect(x: 0, y: 40, width: windowSize.width, height: windowSize.height - 70))
                scrollView.drawsBackground = true
                scrollView.borderType = .noBorder
                scrollView.hasVerticalScroller = true
                scrollView.hasHorizontalScroller = true
                scrollView.autoresizingMask = [.width, .height]
                
                // Configure the document view (image view)
                imageView.autoresizingMask = [.width, .height]
                // Make sure the frame is large enough to see the image but not too large
                let frameWidth = max(viewWidth, scrollView.frame.width)
                let frameHeight = max(viewHeight, scrollView.frame.height)
                imageView.frame = NSRect(x: 0, y: 0, width: frameWidth, height: frameHeight)
                scrollView.documentView = imageView
                
                // Create text label for the prompt with better styling
                let label = NSTextField(frame: NSRect(x: 10, y: 5, width: windowSize.width - 20, height: 30))
                label.stringValue = "Generated image for: \(content)"
                label.isEditable = false
                label.isBordered = false
                label.backgroundColor = .clear
                label.textColor = .labelColor
                label.alignment = .center
                label.font = NSFont.boldSystemFont(ofSize: 14)
                label.maximumNumberOfLines = 2
                label.lineBreakMode = .byTruncatingTail
                label.preferredMaxLayoutWidth = windowSize.width - 20
                
                // Create container view
                let containerView = NSView(frame: NSRect(origin: .zero, size: windowSize.size))
                containerView.wantsLayer = true
                containerView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
                
                containerView.addSubview(scrollView)
                containerView.addSubview(label)
                
                self.contentView = containerView
            } else {
                print("Falling back to SwiftUI view for image display")
                // Fall back to SwiftUI view
                let contentView = ResponseView(
                    content: content.isEmpty && !images.isEmpty ? "Image generated successfully!" : content,
                    selectedText: selectedText,
                    option: option,
                    images: images
                )
                self.contentView = NSHostingView(rootView: contentView)
            }
        } else {
            // Regular text response
            let contentView = ResponseView(
                content: content,
                selectedText: selectedText,
                option: option,
                images: images
            )
            self.contentView = NSHostingView(rootView: contentView)
        }
        
        self.center()
        self.setFrameAutosaveName("ResponseWindow")
        
        // Log the window creation
        if !images.isEmpty {
            print("Created image response window with size: \(windowSize.size.width) x \(windowSize.size.height), image count: \(images.count), image sizes: \(images.map { $0.count })")
        }
    }
    
    override func close() {
        // Notify WindowManager to clean up
        WindowManager.shared.removeResponseWindow(self)
        super.close()
    }
}
