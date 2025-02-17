import SwiftUI
import KeyboardShortcuts
import Carbon.HIToolbox

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private static var sharedStatusItem: NSStatusItem?
    
    // Keep track if the user triggered the app from a service
    private var isServiceTriggered = false
    
    // The single status bar item (pencil icon)
    var statusBarItem: NSStatusItem! {
        get {
            if AppDelegate.sharedStatusItem == nil {
                AppDelegate.sharedStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
                configureStatusBarItem()
            }
            return AppDelegate.sharedStatusItem
        }
        set {
            AppDelegate.sharedStatusItem = newValue
        }
    }
    
    // Your shared app state
    let appState = AppState.shared
    
    // Windows
    private var settingsWindow: NSWindow?
    private(set) var popupWindow: PopupWindow?
    
    // Track shift key state
    private var lastLeftShiftPress: Date?
    private let doubleShiftInterval: TimeInterval = 0.3 // 300ms window for double press
    
    // Event monitor for global keyboard events
    private var eventMonitor: Any?

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Optionally force dark mode look:
        NSApp.appearance = NSAppearance(named: .darkAqua)

        // Provide Services
        NSApp.servicesProvider = self
        
        // Setup the menu bar icon + menu
        setupMenuBar()
        
        // Setup global event monitor for double shift detection
        setupDoubleShiftMonitor()
        
        // Note: We're no longer using the KeyboardShortcuts package for the main shortcut
        // as we're using double-shift instead
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup if needed
    }

    // MARK: - Status Bar

    private func configureStatusBarItem() {
        guard let button = statusBarItem?.button else { return }
        button.image = NSImage(systemSymbolName: "pencil.circle", accessibilityDescription: "AI Assistant")
    }

    private func setupMenuBar() {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "Settings", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Reset App", action: #selector(resetApp), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusBarItem.menu = menu
    }

    // MARK: - Show / Toggle Popup

    private func togglePopup() {
        if let window = popupWindow {
            // If popup is open, close
            closePopupWindow()
            // Clear clipboard when dismissing with double shift
            NSPasteboard.general.clearContents()
        } else {
            // Else, show popup
            showPopup()
        }
    }
    
    private func showPopup() {
        // If already open, do nothing
        guard popupWindow == nil else { return }
        
        // Cancel any ongoing AI request
        appState.activeProvider.cancel()
        
        // NEW CODE: Store which app was frontmost.
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            appState.previousApplication = frontApp
        }
        
        // Create the popup window
        let window = PopupWindow(appState: appState)
        window.delegate = self
        
        popupWindow = window
        
        // For example, we want a 400x400 window:
        window.setContentSize(NSSize(width: 400, height: 400))
        window.positionNearMouse()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }
    
    private func closePopupWindow() {
        if let existingWindow = popupWindow {
            existingWindow.delegate = nil
            existingWindow.cleanup()
            existingWindow.close()
            
            // Clear clipboard with a small delay to ensure proper timing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NSPasteboard.general.clearContents()
            }
        }
        popupWindow = nil
    }

    // MARK: - Settings

    @objc private func showSettings() {
        settingsWindow?.close()
        settingsWindow = nil

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "Settings"
        newWindow.center()
        newWindow.isReleasedWhenClosed = false
        newWindow.delegate = self
        
        let settingsView = SettingsView(appState: appState, showOnlyApiSetup: false)
        let hostingView = NSHostingView(rootView: settingsView)
        newWindow.contentView = hostingView
        newWindow.level = .floating
        
        settingsWindow = newWindow
        
        NSApp.activate(ignoringOtherApps: true)
        newWindow.makeKeyAndOrderFront(nil)
        newWindow.orderFrontRegardless()
    }

    // MARK: - Reset
    
    @objc private func resetApp() {
        AppSettings.shared.resetAll()
        
        recreateStatusBarItem()
        setupMenuBar()

        let alert = NSAlert()
        alert.messageText = "App Reset Complete"
        alert.informativeText = "The app has been reset. Please restart if necessary."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func recreateStatusBarItem() {
        AppDelegate.sharedStatusItem = nil
        _ = self.statusBarItem
    }

    // MARK: - Window Delegate
    
    func windowWillClose(_ notification: Notification) {
        guard let closedWindow = notification.object as? NSWindow else { return }
        
        if closedWindow == popupWindow {
            popupWindow = nil
        }
        else if closedWindow == settingsWindow {
            settingsWindow = nil
        }
    }

    private func setupDoubleShiftMonitor() {
        // Monitor for key down events to detect shift presses
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            guard let self = self else { return }
            
            // Handle only left shift key (keycode 56)
            if event.keyCode == 56 {
                let now = Date()
                
                if event.modifierFlags.contains(.shift) {
                    // Shift pressed
                    if let lastPress = self.lastLeftShiftPress,
                       now.timeIntervalSince(lastPress) < self.doubleShiftInterval {
                        // Double press detected
                        DispatchQueue.main.async {
                            self.togglePopup()
                        }
                        self.lastLeftShiftPress = nil
                    } else {
                        self.lastLeftShiftPress = now
                    }
                }
            } else {
                // Reset the shift press state if any other key is pressed
                self.lastLeftShiftPress = nil
            }
        }
    }
    
    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

