//
//  StartSmartApp.swift
//  StartSmart
//
//  Created by StartSmart Team on 9/11/25.
//

import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
struct StartSmartApp: App {
    
    init() {
        // Configure Firebase
        FirebaseApp.configure()
        
        // Configure Google Sign In
        configureGoogleSignIn()
        
        // Initialize alarm notification coordinator to handle notifications even when app is in background
        _ = AlarmNotificationCoordinator.shared
        
        // NOTE: Defer heavy dependency initialization to avoid blocking UI responsiveness during startup.
        // Full initialization is triggered later by specific features as needed.
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
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