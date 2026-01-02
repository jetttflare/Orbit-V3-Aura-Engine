//
//  MessageComposerModule.swift
//  JarvisIronMan
//
//  Native iOS module for composing iMessage/SMS from React Native.
//  Bridges to the Messages framework for seamless communication.
//

#if os(iOS)
import Foundation
import MessageUI
import UIKit

#if canImport(React)
import React
#endif

// MARK: - Message Composer Module

/// React Native bridge module for composing iMessages and SMS.
/// Exposes `composeMessage` method to JavaScript.
@objc(MessageComposer)
class MessageComposerModule: NSObject {
    
    // MARK: - Properties
    
    private var messageController: MFMessageComposeViewController?
    private var completionHandler: ((Bool) -> Void)?
    
    /// Thread-safe queue for message operations
    private let messageQueue = DispatchQueue(label: "com.jarvis.messagecomposer", qos: .userInteractive)
    
    // MARK: - React Native Bridge
    
    /// Indicates this module should be initialized on the main queue
    @objc static func requiresMainQueueSetup() -> Bool {
        return true
    }
    
    /// Module name for React Native
    @objc static func moduleName() -> String {
        return "MessageComposer"
    }
    
    // MARK: - Public Methods
    
    /// Check if the device can send text messages
    /// - Returns: True if messaging is available
    @objc func canSendText() -> Bool {
        return MFMessageComposeViewController.canSendText()
    }
    
    /// Compose and present a message for the user to send
    /// - Parameters:
    ///   - body: The message body text
    ///   - recipients: Array of recipient phone numbers
    @objc func composeMessage(_ body: String, recipients: [String]) {
        messageQueue.async { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.presentMessageComposer(body: body, recipients: recipients)
            }
        }
    }
    
    /// Compose message with callback for completion
    /// - Parameters:
    ///   - body: The message body text
    ///   - recipients: Array of recipient phone numbers
    ///   - resolve: Promise resolve callback
    ///   - reject: Promise reject callback
    @objc func composeMessageWithPromise(
        _ body: String,
        recipients: [String],
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        guard MFMessageComposeViewController.canSendText() else {
            reject("MESSAGE_NOT_AVAILABLE", "Device cannot send text messages", nil)
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.completionHandler = { success in
                if success {
                    resolve(["status": "sent", "recipients": recipients])
                } else {
                    reject("MESSAGE_CANCELLED", "User cancelled message composition", nil)
                }
            }
            
            self.presentMessageComposer(body: body, recipients: recipients)
        }
    }
    
    /// Send a silent message (for background operations - requires special entitlements)
    /// This is a placeholder for future implementation with proper entitlements
    @objc func sendSilentMessage(
        _ body: String,
        recipients: [String],
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        // Note: Silent messaging requires special entitlements and is not available
        // to regular App Store apps. This is a placeholder.
        reject(
            "SILENT_NOT_AVAILABLE",
            "Silent messaging requires special entitlements. Use composeMessage instead.",
            nil
        )
    }
    
    // MARK: - Private Methods
    
    /// Present the message composer view controller
    private func presentMessageComposer(body: String, recipients: [String]) {
        guard MFMessageComposeViewController.canSendText() else {
            print("[MessageComposer] Device cannot send text messages")
            completionHandler?(false)
            return
        }
        
        // Create and configure the message controller
        let controller = MFMessageComposeViewController()
        controller.body = body
        controller.recipients = recipients
        controller.messageComposeDelegate = self
        
        // Store reference
        messageController = controller
        
        // Get the root view controller
        guard let rootVC = self.getRootViewController() else {
            print("[MessageComposer] Could not find root view controller")
            completionHandler?(false)
            return
        }
        
        // Present the controller
        rootVC.present(controller, animated: true) {
            print("[MessageComposer] Message composer presented")
        }
    }
    
    /// Get the root view controller for presentation
    private func getRootViewController() -> UIViewController? {
        // Try to get from scene on iOS 13+
        if #available(iOS 13.0, *) {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }?
                .rootViewController
        }
        
        // Fallback for older iOS
        return UIApplication.shared.keyWindow?.rootViewController
    }
}

// MARK: - MFMessageComposeViewControllerDelegate

extension MessageComposerModule: MFMessageComposeViewControllerDelegate {
    
    func messageComposeViewController(
        _ controller: MFMessageComposeViewController,
        didFinishWith result: MessageComposeResult
    ) {
        // Dismiss the controller
        controller.dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            
            switch result {
            case .cancelled:
                print("[MessageComposer] Message cancelled")
                self.completionHandler?(false)
                
            case .sent:
                print("[MessageComposer] Message sent")
                self.completionHandler?(true)
                
            case .failed:
                print("[MessageComposer] Message failed")
                self.completionHandler?(false)
                
            @unknown default:
                print("[MessageComposer] Unknown result")
                self.completionHandler?(false)
            }
            
            // Clean up
            self.messageController = nil
            self.completionHandler = nil
        }
    }
}

// MARK: - React Native Type Aliases (for compilation without React Native)

#if !canImport(React)
typealias RCTPromiseResolveBlock = ([String: Any]) -> Void
typealias RCTPromiseRejectBlock = (String, String, Error?) -> Void
#endif

// MARK: - MessageComposerModuleBridge

/// Objective-C bridge for React Native
@objc(MessageComposerModuleBridge)
class MessageComposerModuleBridge: NSObject {
    
    @objc static func requiresMainQueueSetup() -> Bool {
        return true
    }
    
    // Bridge methods exposed to React Native
    
    @objc func canSendText(_ callback: RCTResponseSenderBlock) {
        let canSend = MFMessageComposeViewController.canSendText()
        callback([canSend])
    }
    
    @objc func composeMessage(_ body: String, recipients: [String]) {
        let module = MessageComposerModule()
        module.composeMessage(body, recipients: recipients)
    }
}

#if !canImport(React)
typealias RCTResponseSenderBlock = ([Any]) -> Void
#endif

// MARK: - MessageComposer Bridge Header (for React Native integration)

/*
 Add to your bridging header:
 
 #import <React/RCTBridgeModule.h>
 #import <React/RCTEventEmitter.h>
 
 And register the module in your AppDelegate:
 
 #import <React/RCTBridge.h>
 
 - (NSArray<id<RCTBridgeModule>> *)extraModulesForBridge:(RCTBridge *)bridge {
   return @[[MessageComposerModule new]];
 }
*/

// MARK: - Jarvis Integration

/// Extended message composer with Jarvis-specific features
class JarvisMessageComposer {
    
    static let shared = JarvisMessageComposer()
    
    private let module = MessageComposerModule()
    
    /// Send a follow-up message for a Jarvis task
    /// - Parameters:
    ///   - taskName: Name of the task
    ///   - recipients: List of recipient phone numbers
    func sendTaskFollowUp(taskName: String, recipients: [String]) {
        let body = "Follow-up on: \(taskName)\n\nSent from Jarvis"
        module.composeMessage(body, recipients: recipients)
    }
    
    /// Send a reminder message
    /// - Parameters:
    ///   - message: Reminder message
    ///   - recipient: Recipient phone number
    func sendReminder(message: String, recipient: String) {
        let body = "🔔 Reminder: \(message)\n\nSent from Jarvis"
        module.composeMessage(body, recipients: [recipient])
    }
    
    /// Send a status update
    /// - Parameters:
    ///   - status: Status message
    ///   - recipients: List of recipient phone numbers
    func sendStatusUpdate(status: String, recipients: [String]) {
        let body = "📊 Status Update:\n\(status)\n\nSent from Jarvis"
        module.composeMessage(body, recipients: recipients)
    }
}

// MARK: - Preview Support

#if DEBUG
import SwiftUI

struct MessageComposerPreview: View {
    @State private var showingComposer = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Message Composer")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Button("Compose Message") {
                showingComposer = true
            }
            .buttonStyle(.borderedProminent)
            
            if !MFMessageComposeViewController.canSendText() {
                Text("⚠️ Device cannot send text messages")
                    .foregroundColor(.orange)
            }
        }
        .padding()
    }
}

#Preview {
    MessageComposerPreview()
}
#endif
#endif
