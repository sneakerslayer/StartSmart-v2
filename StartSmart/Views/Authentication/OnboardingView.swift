//
//  OnboardingView.swift
//  StartSmart
//
//  Created by StartSmart Team on 9/11/25.
//

import SwiftUI
import AuthenticationServices

/// Onboarding view with social login options
struct OnboardingView: View {
    @StateObject private var authService = DependencyContainer.shared.authenticationService as! AuthenticationService
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isSigningIn = false
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    // Header Section
                    headerSection
                        .frame(height: geometry.size.height * 0.4)
                    
                    // Content Section
                    contentSection
                        .frame(minHeight: geometry.size.height * 0.6)
                        .background(Color(.systemBackground))
                        .clipShape(
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                        )
                        .offset(y: -30)
                }
            }
            .background(
                LinearGradient(
                    colors: [.blue.opacity(0.8), .purple.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .ignoresSafeArea(.all, edges: .top)
        }
        .alert("Authentication Error", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // App Icon/Logo
            Image(systemName: "alarm.waves.left.and.right")
                .font(.system(size: 80, weight: .light))
                .foregroundColor(.white)
            
            // App Title
            Text("StartSmart")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            // Tagline
            Text("Wake up with purpose, powered by AI")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
    
    // MARK: - Content Section
    
    private var contentSection: some View {
        VStack(spacing: 30) {
            VStack(spacing: 16) {
                Text("Get Started")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Transform your mornings with personalized AI-generated motivational content")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(.top, 40)
            
            // Features List
            featuresSection
            
            Spacer(minLength: 40)
            
            // Sign In Buttons
            authenticationButtons
            
            // Terms and Privacy
            termsSection
        }
        .padding(.horizontal, 30)
        .padding(.bottom, 40)
    }
    
    // MARK: - Features Section
    
    private var featuresSection: some View {
        VStack(spacing: 16) {
            FeatureRow(
                icon: "brain.head.profile",
                title: "AI-Powered Content",
                description: "Personalized motivational speeches generated just for you"
            )
            
            FeatureRow(
                icon: "speaker.wave.3",
                title: "Natural Voice",
                description: "High-quality text-to-speech with personality"
            )
            
            FeatureRow(
                icon: "lock.shield",
                title: "Privacy First",
                description: "Your data stays secure and private"
            )
        }
        .padding(.horizontal, 10)
    }
    
    // MARK: - Authentication Buttons
    
    private var authenticationButtons: some View {
        VStack(spacing: 16) {
            // Sign in with Apple
            SignInWithAppleButton(.signIn) { request in
                // This will be handled by the AuthenticationService
            } onCompletion: { result in
                handleAppleSignInResult(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .disabled(isSigningIn)
            
            // Sign in with Google
            Button {
                handleGoogleSignIn()
            } label: {
                HStack {
                    Image(systemName: "globe")
                        .font(.title2)
                    
                    Text("Continue with Google")
                        .font(.system(size: 18, weight: .semibold))
                    
                    Spacer()
                }
                .foregroundColor(.primary)
                .frame(height: 56)
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
            }
            .disabled(isSigningIn)
            
            // Continue as Guest Button
            Button {
                handleGuestMode()
            } label: {
                HStack {
                    Image(systemName: "person.crop.circle")
                        .font(.title2)
                    
                    Text("Continue as Guest")
                        .font(.system(size: 18, weight: .semibold))
                    
                    Spacer()
                }
                .foregroundColor(.secondary)
                .frame(height: 56)
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6).opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
            }
            .disabled(isSigningIn)
            
            if isSigningIn {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Signing in...")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
        }
    }
    
    // MARK: - Terms Section
    
    private var termsSection: some View {
        VStack(spacing: 8) {
            Text("By continuing, you agree to our")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            HStack(spacing: 4) {
                Button("Terms of Service") {
                    // Handle terms of service
                }
                .font(.system(size: 12, weight: .medium))
                
                Text("and")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Button("Privacy Policy") {
                    // Handle privacy policy
                }
                .font(.system(size: 12, weight: .medium))
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - Authentication Handlers
    
    private func handleAppleSignInResult(_ result: Result<ASAuthorization, Error>) {
        isSigningIn = true
        
        Task {
            do {
                _ = try await authService.signInWithApple()
                // Navigation will be handled by the app state
            } catch {
                await MainActor.run {
                    alertMessage = error.localizedDescription
                    showingAlert = true
                    isSigningIn = false
                }
            }
        }
    }
    
    private func handleGoogleSignIn() {
        isSigningIn = true
        
        Task {
            do {
                _ = try await authService.signInWithGoogle()
                // Navigation will be handled by the app state
            } catch {
                await MainActor.run {
                    alertMessage = error.localizedDescription
                    showingAlert = true
                    isSigningIn = false
                }
            }
        }
    }
    
    private func handleGuestMode() {
        // Enable guest mode - user can access free features without authentication
        authService.enableGuestMode()
        // Navigation will be handled by the app state
    }
}

// MARK: - Feature Row Component

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
}
