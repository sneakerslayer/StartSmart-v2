//
//  StartSmartApp.swift
//  StartSmart
//
//  Created by StartSmart Team on 9/11/25.
//

import SwiftUI
import FirebaseCore
import GoogleSignIn
import NotificationCenter
import os.log
import UIKit

@main
struct StartSmartApp: App {
    private let logger = Logger(subsystem: "com.startsmart.mobile", category: "StartSmartApp")
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // Configure Firebase
        FirebaseApp.configure()
        
        // Configure Google Sign In
        configureGoogleSignIn()
        
        // Initialize alarm notification coordinator to handle notifications even when app is in background
        _ = AlarmNotificationCoordinator.shared
        
        // Initialize alarm dismissal state manager
        _ = AlarmDismissalStateManager.shared
        
        // Check for pending alarm dismissal on app launch
        checkForPendingAlarmDismissal()
        
        // Set up app lifecycle observers for alarm preloading
        setupAppLifecycleObservers()
        
        // Set up notification observer for WakeUpIntent
        NotificationCenter.default.addObserver(
            forName: .showAlarmView,
            object: nil,
            queue: .main
        ) { notification in
            logger.info("🎯 WakeUpIntent notification received: \(notification.userInfo ?? [:])")
            // The notification will be handled by MainAppView
        }
        
        // NOTE: Defer heavy dependency initialization to avoid blocking UI responsiveness during startup.
        // Full initialization is triggered later by specific features as needed.
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    handleDeepLink(url: url)
                }
                .onAppear {
                    // Check again when view appears (in case app was terminated)
                    checkForPendingAlarmDismissal()
                }
        }
    }
    
    private func handleDeepLink(url: URL) {
        logger.info("🔗 Deep link received: \(url.absoluteString)")
        
        guard url.scheme == "startsmart" else {
            logger.warning("⚠️ Unknown URL scheme: \(url.scheme ?? "nil")")
            return
        }
        
        if url.host == "alarm" {
            // Parse alarm ID from URL: startsmart://alarm/{alarmId}?goal={goal}
            let pathComponents = url.pathComponents.filter { $0 != "/" }
            
            if let alarmId = pathComponents.first {
                logger.info("✅ Parsed alarm ID from deep link: \(alarmId)")
                
                // Get user goal from query parameters
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                let userGoal = components?.queryItems?.first(where: { $0.name == "goal" })?.value
                
                // Store dismissal state
                AlarmDismissalStateManager.shared.storePendingDismissal(
                    alarmId: alarmId,
                    userGoal: userGoal
                )
                
                // Post notification to show AlarmView
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    NotificationCenter.default.post(
                        name: .showAlarmView,
                        object: nil,
                        userInfo: [
                            "alarmID": alarmId,
                            "userGoal": userGoal ?? "",
                            "wakeupMethod": "deep_link"
                        ]
                    )
                }
            } else {
                logger.error("❌ No alarm ID found in deep link URL")
            }
        }
    }
    
    private func checkForPendingAlarmDismissal() {
        logger.info("🔍 Checking for pending alarm dismissal on app launch...")
        
        if let dismissal = AlarmDismissalStateManager.shared.getPendingDismissal() {
            logger.info("✅ Found pending dismissal for alarm: \(dismissal.alarmId)")
            
            // Track app launch detection success
            Task {
                await AlarmErrorTrackingService.shared.trackAppLaunchDetection(
                    source: "app_init",
                    alarmId: dismissal.alarmId,
                    success: true
                )
            }
            
            // Post notification to trigger AlarmView presentation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NotificationCenter.default.post(
                    name: .showAlarmView,
                    object: nil,
                    userInfo: [
                        "alarmID": dismissal.alarmId,
                        "userGoal": dismissal.userGoal ?? "",
                        "wakeupMethod": "app_launch_detection"
                    ]
                )
            }
        } else {
            logger.info("ℹ️ No pending dismissal found")
            
            // Track that we checked but found nothing
            Task {
                await AlarmErrorTrackingService.shared.trackAppLaunchDetection(
                    source: "app_init",
                    alarmId: nil,
                    success: false
                )
            }
        }
    }
    
    private func setupAppLifecycleObservers() {
        // Observe app becoming active to preload alarms
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.logger.info("📱 App became active - triggering alarm preload")
            // Trigger alarm preload via notification
            NotificationCenter.default.post(
                name: .preloadAlarms,
                object: nil
            )
        }
        
        // Observe app entering foreground
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.logger.info("📱 App entering foreground - triggering alarm preload")
            NotificationCenter.default.post(
                name: .preloadAlarms,
                object: nil
            )
        }
    }
    
    private func configureGoogleSignIn() {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientId = plist["CLIENT_ID"] as? String else {
            print("Warning: GoogleService-Info.plist not found or CLIENT_ID missing")
            return
        }
        
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
    }
}

// MARK: - App Delegate for URL Handling
class AppDelegate: NSObject, UIApplicationDelegate {
    private let logger = Logger(subsystem: "com.startsmart.mobile", category: "AppDelegate")
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        logger.info("🔗 AppDelegate received URL: \(url.absoluteString)")
        
        // Handle deep link
        if url.scheme == "startsmart" {
            NotificationCenter.default.post(
                name: .handleDeepLink,
                object: nil,
                userInfo: ["url": url]
            )
            return true
        }
        
        return false
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Check if app was launched from URL
        if let url = launchOptions?[.url] as? URL {
            logger.info("🚀 App launched from URL: \(url.absoluteString)")
            handleDeepLink(url: url)
        }
        
        return true
    }
    
    private func handleDeepLink(url: URL) {
        logger.info("🔗 AppDelegate handling deep link: \(url.absoluteString)")
        
        guard url.scheme == "startsmart" else { return }
        
        if url.host == "alarm" {
            let pathComponents = url.pathComponents.filter { $0 != "/" }
            
            if let alarmId = pathComponents.first {
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                let userGoal = components?.queryItems?.first(where: { $0.name == "goal" })?.value
                
                AlarmDismissalStateManager.shared.storePendingDismissal(
                    alarmId: alarmId,
                    userGoal: userGoal
                )
            }
        }
    }