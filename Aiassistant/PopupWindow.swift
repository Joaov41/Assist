import SwiftUI

class PopupWindow: NSWindow {
    private var hostingController: NSHostingController<PopupView>?
    
    init(appState: AppState) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
            styleMask: [.closable, .resizable, .miniaturizable, .fullSizeContentView, .titled],
            backing: .buffered,
            defer: false
        )
        
        let popupView = PopupView(appState: appState)
        self.hostingController = NSHostingController(rootView: popupView)
        self.contentView = hostingController?.view
        self.isReleasedWhenClosed = false
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.level = .floating
        self.backgroundColor = .clear
        self.isOpaque = false
        
        // Set minimum window size
        self.minSize = NSSize(width: 300, height: 400)
        
        // Allow the window to be resized to any size
        self.maxSize = NSSize(width: CGFloat.infinity, height: CGFloat.infinity)
        
        // Make sure content view is resizable
        self.contentView?.autoresizingMask = [.width, .height]
        
        // Set content size
        self.setContentSize(NSSize(width: 400, height: 500))
    }
    
    func cleanup() {
        hostingController = nil
    }
}

extension NSWindow {
    func positionNearMouse() {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first {
            NSMouseInRect(mouseLocation, $0.frame, false)
        }

        if let screen = screen {
            let windowSize = self.frame.size
            let yFlipped = screen.frame.maxY - mouseLocation.y
            let origin = NSPoint(
                x: mouseLocation.x - windowSize.width / 2,
                y: yFlipped - windowSize.height / 2
            )
            self.setFrameOrigin(origin)
        }
    }
}
