import SwiftUI
import Firebase
import GoogleSignIn

@main
struct StartSmartApp: App {
    
    init() {
        // Configure Firebase
        FirebaseConfiguration.configure()
        
        // Configure Google Sign In
        configureGoogleSignIn()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(DependencyContainer.shared.authenticationService)
                .environmentObject(DependencyContainer.shared.firebaseService)
        }
    }
    
    private func configureGoogleSignIn() {
        // Google Sign In configuration will be set up when GoogleService-Info.plist is added
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientId = plist["CLIENT_ID"] as? String else {
            print("Warning: GoogleService-Info.plist not found or CLIENT_ID missing")
            return
        }
        
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
    }
}
