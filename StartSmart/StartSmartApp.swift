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