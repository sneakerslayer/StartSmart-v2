//
//  AuthenticationView.swift
//  StartSmart
//
//  Created by StartSmart Team on 9/11/25.
//

import SwiftUI

/// Main authentication view that handles authentication state and navigation
struct AuthenticationView: View {
    @StateObject private var authService = DependencyContainer.shared.authenticationService as! AuthenticationService
    @State private var showingOnboarding = true
    
    var body: some View {
        Group {
            switch authService.authenticationState {
            case .signedOut:
                OnboardingView()
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                
            case .signingIn:
                SigningInView()
                    .transition(.opacity)
                
            case .signedIn:
                // This will be replaced with the main app view in future tasks
                SignedInView()
                    .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing)))
                
            case .error(let error):
                ErrorView(error: error) {
                    // Retry action
                    Task {
                        await authService.updateAuthenticationState()
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authService.isAuthenticated)
    }
}

// MARK: - Signing In View

struct SigningInView: View {
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "alarm.waves.left.and.right")
                .font(.system(size: 60, weight: .light))
                .foregroundColor(.blue)
            
            VStack(spacing: 16) {
                Text("Signing you in...")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Setting up your personalized alarm experience")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            ProgressView()
                .scaleEffect(1.5)
                .tint(.blue)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Signed In View (Temporary)

struct SignedInView: View {
    @StateObject private var authService = DependencyContainer.shared.authenticationService as! AuthenticationService
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("Welcome to StartSmart!")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)
                    
                    if let user = authService.currentUser {
                        Text("Hello, \(user.displayName ?? "User")")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Your authentication is complete. The main app experience will be implemented in the next phases.")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                
                VStack(spacing: 16) {
                    Button("View Profile") {
                        // This will be implemented in future tasks
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    
                    Button("Sign Out") {
                        Task {
                            try? await authService.signOut()
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
            .padding(.horizontal, 30)
            .navigationTitle("StartSmart")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Error View

struct ErrorView: View {
    let error: Error
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            VStack(spacing: 16) {
                Text("Something went wrong")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(error.localizedDescription)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Try Again") {
                retryAction()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .medium))
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    AuthenticationView()
}
