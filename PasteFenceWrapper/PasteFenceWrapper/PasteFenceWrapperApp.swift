//
//  PasteFenceWrapperApp.swift
//  PasteFenceWrapper
//
//  Created by Choru on 12/10/25.
//

import SwiftUI
import AppKit

@main
struct PasteFenceWrapperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menu bar only - no main window for menu bar app
        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var previewController: PreviewWindowController?

    static var isUITesting: Bool {
        CommandLine.arguments.contains("--ui-testing")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if AppDelegate.isUITesting {
            // Show preview window with sample data for UI testing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showTestPreviewWindow()
            }
        }
    }

    func showTestPreviewWindow() {
        let sampleOriginal = """
        Contact: John Doe
        Email: john.doe@example.com
        Phone: (555) 123-4567
        API Key: sk-test1234567890abcdefghij
        """

        let sampleMasked = """
        Contact: John Doe
        Email: [EMAIL_MASKED]
        Phone: [PHONE_MASKED]
        API Key: [API_KEY_MASKED]
        """

        // Create sample detected items with valid ranges
        let emailRange = sampleOriginal.range(of: "john.doe@example.com")!
        let phoneRange = sampleOriginal.range(of: "(555) 123-4567")!
        let apiKeyRange = sampleOriginal.range(of: "sk-test1234567890abcdefghij")!

        let sampleItems = [
            DetectedItem(
                text: "john.doe@example.com",
                type: .email,
                range: emailRange,
                confidence: 1.0,
                source: .regex,
                ruleName: "Email Address"
            ),
            DetectedItem(
                text: "(555) 123-4567",
                type: .phone,
                range: phoneRange,
                confidence: 1.0,
                source: .regex,
                ruleName: "Phone Number"
            ),
            DetectedItem(
                text: "sk-test1234567890abcdefghij",
                type: .apiKey,
                range: apiKeyRange,
                confidence: 0.95,
                source: .regex,
                ruleName: "OpenAI API Key"
            )
        ]

        previewController = PreviewWindowController(
            original: sampleOriginal,
            masked: sampleMasked,
            detectedItems: sampleItems
        ) { [weak self] _ in
            self?.previewController = nil
        }
        previewController?.showWindow(nil)
    }
}
