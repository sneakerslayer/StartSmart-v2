import SwiftUI

struct ContentView: View {
    @StateObject private var authService = DependencyContainer.shared.authenticationService as! AuthenticationService
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                // Main app content will be implemented in Phase 3+
                MainAppView()
            } else {
                // Show authentication flow
                AuthenticationView()
            }
        }
        .onAppear {
            // Initialize authentication state
            Task {
                await authService.updateAuthenticationState()
            }
        }
    }
}

// MARK: - Main App View (Placeholder)

struct MainAppView: View {
    @StateObject private var authService = DependencyContainer.shared.authenticationService as! AuthenticationService
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                VStack(spacing: 16) {
                    Image(systemName: "alarm.waves.left.and.right")
                        .font(.system(size: 60, weight: .light))
                        .foregroundColor(.blue)
                    
                    Text("StartSmart")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("AI-Powered Motivational Alarms")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                    
                    if let user = authService.currentUser {
                        Text("Welcome back, \(user.displayName)!")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.blue)
                    }
                }
                
                VStack(spacing: 20) {
                    Text("🚧 Under Construction 🚧")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.orange)
                    
                    Text("The main alarm interface will be implemented in Phase 3: Core Alarm Infrastructure")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                    
                    Text("Authentication is complete and working perfectly!")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.green)
                        .padding(.horizontal, 30)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                Button("Sign Out") {
                    Task {
                        try? await authService.signOut()
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
                .padding(.horizontal, 30)
            }
            .padding(.top, 40)
            .navigationTitle("StartSmart")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ContentView()
}
