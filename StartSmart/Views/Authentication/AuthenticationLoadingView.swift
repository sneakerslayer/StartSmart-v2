//
//  AuthenticationLoadingView.swift
//  StartSmart
//
//  Created by StartSmart Team on 9/11/25.
//

import SwiftUI

/// Loading view for authentication processes
struct AuthenticationLoadingView: View {
    let title: String
    let subtitle: String
    @State private var rotationAngle: Double = 0
    
    init(title: String = "Signing you in...", subtitle: String = "Setting up your personalized alarm experience") {
        self.title = title
        self.subtitle = subtitle
    }
    
    var body: some View {
        VStack(spacing: 40) {
            // Animated logo
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.2), lineWidth: 4)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(rotationAngle))
                    .animation(
                        .linear(duration: 2)
                        .repeatForever(autoreverses: false),
                        value: rotationAngle
                    )
                
                Image(systemName: "alarm.waves.left.and.right")
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 16) {
                Text(title)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .onAppear {
            rotationAngle = 360
        }
    }
}

// MARK: - Success View

struct AuthenticationSuccessView: View {
    let userName: String
    @State private var showCheckmark = false
    @State private var showText = false
    
    var body: some View {
        VStack(spacing: 30) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .scaleEffect(showCheckmark ? 1.2 : 0.8)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showCheckmark)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                    .scaleEffect(showCheckmark ? 1.0 : 0.5)
                    .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2), value: showCheckmark)
            }
            
            VStack(spacing: 16) {
                Text("Welcome to StartSmart!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                    .opacity(showText ? 1 : 0)
                    .animation(.easeInOut(duration: 0.5).delay(0.5), value: showText)
                
                Text("Hello, \(userName)")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
                    .opacity(showText ? 1 : 0)
                    .animation(.easeInOut(duration: 0.5).delay(0.7), value: showText)
                
                Text("Your personalized alarm experience is ready!")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .opacity(showText ? 1 : 0)
                    .animation(.easeInOut(duration: 0.5).delay(0.9), value: showText)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .onAppear {
            showCheckmark = true
            showText = true
        }
    }
}

// MARK: - Error State View

struct AuthenticationErrorView: View {
    let error: Error
    let retryAction: () -> Void
    @State private var showContent = false
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
                .scaleEffect(showContent ? 1.0 : 0.5)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showContent)
            
            VStack(spacing: 16) {
                Text("Authentication Failed")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(errorMessage(for: error))
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .opacity(showContent ? 1 : 0)
            .animation(.easeInOut(duration: 0.5).delay(0.3), value: showContent)
            
            VStack(spacing: 16) {
                Button("Try Again") {
                    retryAction()
                }
                .buttonStyle(PrimaryButtonStyle())
                
                Button("Need Help?") {
                    // This could open support or FAQ
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .opacity(showContent ? 1 : 0)
            .animation(.easeInOut(duration: 0.5).delay(0.5), value: showContent)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .onAppear {
            showContent = true
        }
    }
    
    private func errorMessage(for error: Error) -> String {
        // Provide user-friendly error messages
        if let authError = error as? AuthenticationError {
            switch authError {
            case .invalidAppleCredentials:
                return "There was an issue with Apple Sign In. Please try again."
            case .invalidGoogleCredentials:
                return "There was an issue with Google Sign In. Please try again."
            case .googleSignInCancelled:
                return "Google Sign In was cancelled. Please try again if you'd like to continue."
            case .noPresentingViewController:
                return "There was a technical issue. Please restart the app and try again."
            default:
                return "Authentication failed. Please check your internet connection and try again."
            }
        }
        
        return "Something went wrong. Please check your internet connection and try again."
    }
}

// MARK: - Preview

#Preview("Loading") {
    AuthenticationLoadingView()
}

#Preview("Success") {
    AuthenticationSuccessView(userName: "John")
}

#Preview("Error") {
    AuthenticationErrorView(error: AuthenticationError.invalidAppleCredentials) {
        print("Retry tapped")
    }
}
