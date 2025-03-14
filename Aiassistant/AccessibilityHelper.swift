import Cocoa
import ApplicationServices

class AccessibilityHelper {
    
    /// Check if the app has proper accessibility permissions
    static func checkAccessibilityPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        print("Accessibility permissions enabled: \(accessEnabled)")
        return accessEnabled
    }
    
    /// Simulate Cmd+C in the frontmost application using HID system state, then read the pasteboard.
    static func copyTextFromFocusedElement() -> String? {
        // First check accessibility permissions
        guard checkAccessibilityPermissions() else {
            print("Error: Accessibility permissions not granted")
            return nil
        }
        
        // Ensure we're working with the correct application
        guard let targetApp = NSWorkspace.shared.frontmostApplication else {
            print("Error: No frontmost application found")
            return nil
        }
        
        // Check if this is a spreadsheet application
        let isSpreadsheetApp = targetApp.bundleIdentifier?.contains("excel") == true || 
                               targetApp.bundleIdentifier?.contains("numbers") == true || 
                               targetApp.bundleIdentifier?.contains("sheets") == true ||
                               targetApp.localizedName?.lowercased().contains("excel") == true ||
                               targetApp.localizedName?.lowercased().contains("numbers") == true ||
                               targetApp.localizedName?.lowercased().contains("sheets") == true
        
        print("Starting copy operation in \(targetApp.localizedName ?? "Unknown")...")
        print("Is spreadsheet app: \(isSpreadsheetApp)")
        
        // Store the current pasteboard contents
        let pasteboard = NSPasteboard.general
        let oldPasteboardContents = pasteboard.string(forType: .string)
        let oldPasteboardChangeCount = pasteboard.changeCount
        print("Initial pasteboard change count: \(oldPasteboardChangeCount)")
        
        // Clear the pasteboard to ensure we don't get stale data
        pasteboard.clearContents()
        Thread.sleep(forTimeInterval: 0.1)
        
        // Create event source targeting the application
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            print("Error creating CGEventSource for simulating copy.")
            return nil
        }
        
        // Ensure we're using the correct key codes
        let cmdKeyCode: CGKeyCode = 0x37  // Command key
        let cKeyCode: CGKeyCode = 0x08    // 'C' key
        
        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: cmdKeyCode, keyDown: true)
        let cDown   = CGEvent(keyboardEventSource: source, virtualKey: cKeyCode, keyDown: true)
        let cUp     = CGEvent(keyboardEventSource: source, virtualKey: cKeyCode, keyDown: false)
        let cmdUp   = CGEvent(keyboardEventSource: source, virtualKey: cmdKeyCode, keyDown: false)
        
        // Set the Command flag on all events
        let commandFlag: CGEventFlags = [.maskCommand]
        cmdDown?.flags = commandFlag
        cDown?.flags = commandFlag
        cUp?.flags = commandFlag
        cmdUp?.flags = commandFlag
        
        // Post the events with longer delays for spreadsheet apps
        print("Sending copy key events to \(targetApp.localizedName ?? "Unknown")...")
        
        // Adjust timing for spreadsheet applications
        let keyDelay = isSpreadsheetApp ? 0.3 : 0.2
        
        // First attempt with appropriate delays
        cmdDown?.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: keyDelay)
        cDown?.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: keyDelay)
        cUp?.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: keyDelay)
        cmdUp?.post(tap: .cghidEventTap)
        
        // Initial delay before checking pasteboard - longer for spreadsheets
        Thread.sleep(forTimeInterval: isSpreadsheetApp ? 0.5 : 0.3)
        
        // Wait for the pasteboard to be updated
        let maxAttempts = isSpreadsheetApp ? 15 : 10 // More attempts for spreadsheets
        var attempts = 0
        var copiedText: String?
        
        print("Waiting for pasteboard update...")
        while attempts < maxAttempts {
            let currentChangeCount = pasteboard.changeCount
            print("Attempt \(attempts + 1): Change count \(currentChangeCount)")
            
            if currentChangeCount != oldPasteboardChangeCount {
                if let text = pasteboard.string(forType: .string), !text.isEmpty {
                    print("Successfully copied text of length: \(text.count)")
                    copiedText = text
                    break
                }
            }
            
            // If we haven't succeeded after half the attempts, try sending the key events again
            if attempts == maxAttempts / 2 {
                print("Retrying copy operation...")
                cmdDown?.post(tap: .cghidEventTap)
                Thread.sleep(forTimeInterval: isSpreadsheetApp ? 0.4 : 0.3)
                cDown?.post(tap: .cghidEventTap)
                Thread.sleep(forTimeInterval: isSpreadsheetApp ? 0.4 : 0.3)
                cUp?.post(tap: .cghidEventTap)
                Thread.sleep(forTimeInterval: isSpreadsheetApp ? 0.4 : 0.3)
                cmdUp?.post(tap: .cghidEventTap)
                Thread.sleep(forTimeInterval: isSpreadsheetApp ? 0.4 : 0.3)
            }
            
            // Wait longer between attempts for spreadsheet apps
            Thread.sleep(forTimeInterval: isSpreadsheetApp ? 0.3 : 0.2)
            attempts += 1
        }
        
        // Restore the original pasteboard contents
        if let oldContent = oldPasteboardContents {
            pasteboard.clearContents()
            Thread.sleep(forTimeInterval: 0.1)
            pasteboard.setString(oldContent, forType: .string)
        }
        
        return copiedText
    }
    
    /// Replace the external app's selected text by placing `newText` on the clipboard, reactivating the app,
    /// and simulating a Cmd+V keystroke using HID system state.
    static func replaceTextInFocusedElement(with newText: String) {
        // Check accessibility permissions first
        guard checkAccessibilityPermissions() else {
            print("Error: Accessibility permissions not granted")
            return
        }
        
        // Get the target application
        guard let targetApp = AppState.shared.previousApplication else {
            print("Error: No target application found")
            return
        }
        
        // Check if this is a spreadsheet application 
        let isSpreadsheetApp = targetApp.bundleIdentifier?.contains("excel") == true || 
                               targetApp.bundleIdentifier?.contains("numbers") == true || 
                               targetApp.bundleIdentifier?.contains("sheets") == true ||
                               targetApp.localizedName?.lowercased().contains("excel") == true ||
                               targetApp.localizedName?.lowercased().contains("numbers") == true ||
                               targetApp.localizedName?.lowercased().contains("sheets") == true
        
        print("Starting paste operation in \(targetApp.localizedName ?? "Unknown")...")
        
        // Store current clipboard content
        let pasteboard = NSPasteboard.general
        let oldClipboard = pasteboard.string(forType: .string)
        
        // Place the new text on the clipboard
        pasteboard.clearContents()
        Thread.sleep(forTimeInterval: 0.1)
        pasteboard.setString(newText, forType: .string)
        
        // Verify the text was placed on the clipboard
        guard let verifyText = pasteboard.string(forType: .string),
              verifyText == newText else {
            print("Error: Failed to place new text on clipboard")
            return
        }
        
        // Ensure the target application is frontmost and active
        if !targetApp.isActive {
            targetApp.activate(options: .activateIgnoringOtherApps)
            // Give applications time to activate
            Thread.sleep(forTimeInterval: 0.3)
        }
        
        // Create event source
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            print("Error: Failed to create CGEventSource for simulating paste.")
            return
        }
        
        // Create key events
        let cmdKeyCode: CGKeyCode = 0x37  // Command key
        let vKeyCode: CGKeyCode = 0x09    // 'V' key
        
        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: cmdKeyCode, keyDown: true)
        let vDown   = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
        let vUp     = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        let cmdUp   = CGEvent(keyboardEventSource: source, virtualKey: cmdKeyCode, keyDown: false)
        
        // Set the Command flag on all events
        let commandFlag: CGEventFlags = [.maskCommand]
        cmdDown?.flags = commandFlag
        vDown?.flags = commandFlag
        vUp?.flags = commandFlag
        cmdUp?.flags = commandFlag
        
        // Send the paste events - longer delays for spreadsheets
        print("Sending paste key events...")
        cmdDown?.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: isSpreadsheetApp ? 0.3 : 0.2)
        vDown?.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: isSpreadsheetApp ? 0.3 : 0.2)
        vUp?.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: isSpreadsheetApp ? 0.3 : 0.2)
        cmdUp?.post(tap: .cghidEventTap)
        
        // For spreadsheet applications, provide more time to process the paste
        let waitTime = isSpreadsheetApp ? 0.5 : 0.3
        print("Waiting \(waitTime) seconds for paste operation to complete...")
        Thread.sleep(forTimeInterval: waitTime)
        
        // Restore the original clipboard content
        if let oldText = oldClipboard {
            pasteboard.clearContents()
            Thread.sleep(forTimeInterval: 0.1)
            pasteboard.setString(oldText, forType: .string)
            print("Restored original clipboard content")
        }
        
        print("Paste operation completed")
    }
}

