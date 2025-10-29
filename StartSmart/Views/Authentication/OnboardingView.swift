//
//  OnboardingView.swift
//  StartSmart
//
//  Created by StartSmart Team on 9/11/25.
//

import SwiftUI
import AuthenticationServices

// MARK: - Design System (matching PremiumLandingPageV2)
fileprivate struct AuthDesignSystem {
    static let darkBg = Color(red: 0.06, green: 0.06, blue: 0.11)
    static let purple = Color(red: 139/255, green: 92/255, blue: 246/255)
    static let indigo = Color(red: 99/255, green: 102/255, blue: 241/255)
    
    static let spacing1: CGFloat = 8
    static let spacing2: CGFloat = 16
    static let spacing3: CGFloat = 24
    static let spacing4: CGFloat = 32
    
    static let radiusMedium: CGFloat = 12
    static let radiusLarge: CGFloat = 20
    
    static func responsiveFontSize(_ baseSize: CGFloat) -> CGFloat {
        let isLargeScreen = UIScreen.main.bounds.width > 600
        return isLargeScreen ? baseSize * 0.85 : baseSize
    }
}

/// Onboarding view with social login options - redesigned to match landing page
struct OnboardingView: View {
    @StateObject private var authService = DependencyContainer.shared.authenticationService as! AuthenticationService
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isSigningIn = false
    @State private var animationStarted = false
    
    var body: some View {
        ZStack {
            // Background matching landing page - ignores safe area
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.06, green: 0.06, blue: 0.11),
                        Color(red: 0.08, green: 0.07, blue: 0.14)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color(red: 139/255, green: 92/255, blue: 246/255).opacity(0.15),
                        Color.clear
                    ]),
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 400
                )
                
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color(red: 99/255, green: 102/255, blue: 241/255).opacity(0.1),
                        Color.clear
                    ]),
                    center: .bottomTrailing,
                    startRadius: 0,
                    endRadius: 300
                )
            }
            .ignoresSafeArea()
            
            // Content - respects safe area
            VStack(alignment: .center, spacing: 0) {
                // Top spacer
                Spacer()
                
                // Header
                VStack(spacing: 4) {
                    Text("Sign In")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Continue to StartSmart")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.bottom, 20)
                
                // Features
                VStack(spacing: 10) {
                    CompactFeatureItem(icon: "brain.head.profile", title: "AI-Powered", description: "Personalized content")
                    CompactFeatureItem(icon: "speaker.wave.3", title: "Natural Voice", description: "High-quality audio")
                    CompactFeatureItem(icon: "lock.shield", title: "Privacy First", description: "Secure & private")
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                
                // Buttons
                VStack(spacing: 12) {
                    SignInWithAppleButton(.signIn) { request in
                        // This will be handled by the AuthenticationService
                    } onCompletion: { result in
                        handleAppleSignInResult(result)
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(isSigningIn)
                    
                    Button {
                        handleGoogleSignIn()
                    } label: {
                        Text("Continue with Google")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(LinearGradient(gradient: Gradient(colors: [AuthDesignSystem.purple.opacity(0.2), AuthDesignSystem.indigo.opacity(0.2)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isSigningIn)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                
                // Legal
                VStack(spacing: 2) {
                    Text("By continuing, you agree to our")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                    
                    HStack(spacing: 3) {
                        Link("Terms of Service", destination: URL(string: "https://www.startsmartmobile.com/support")!)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                        Text("and")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                        Link("Privacy Policy", destination: URL(string: "https://www.startsmartmobile.com/support")!)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(.horizontal, 20)
                
                // Bottom spacer
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.1)) {
                animationStarted = true
            }
        }
        .alert("Authentication Error", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Authentication Handlers
    
    private func handleAppleSignInResult(_ result: Result<ASAuthorization, Error>) {
        isSigningIn = true
        
        Task {
            do {
                _ = try await authService.signInWithApple()
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
            } catch {
                await MainActor.run {
                    alertMessage = error.localizedDescription
                    showingAlert = true
                    isSigningIn = false
                }
            }
        }
    }
}

// MARK: - Compact Feature Item

struct CompactFeatureItem: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(AuthDesignSystem.purple)
            
            Text(title)
                .font(.system(size: AuthDesignSystem.responsiveFontSize(15), weight: .semibold))
                .foregroundColor(.white)
            
            Text(description)
                .font(.system(size: AuthDesignSystem.responsiveFontSize(12), weight: .regular))
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(1)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.04))
        .overlay(
            RoundedRectangle(cornerRadius: AuthDesignSystem.radiusMedium)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .cornerRadius(AuthDesignSystem.radiusMedium)
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
}
