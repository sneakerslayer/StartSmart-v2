//
//  SimpleAuthenticationService.swift
//  StartSmart
//
//  A lightweight authentication service for onboarding without dependency injection
//

import SwiftUI
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
import CryptoKit
import Combine

/// Simple authentication service for onboarding flow that doesn't use dependency injection
class SimpleAuthenticationService: NSObject, ObservableObject, ASAuthorizationControllerPresentationContextProviding {
    
    // MARK: - Published Properties
    
    @Published var isAuthenticated: Bool = false
    @Published var isSigningIn: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    private var currentNonce: String?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        checkAuthenticationStatus()
    }
    
    // MARK: - Authentication Status
    
    private func checkAuthenticationStatus() {
        isAuthenticated = Auth.auth().currentUser != nil
    }
    
    // MARK: - Google Sign In
    
    func signInWithGoogle() async -> Bool {
        await MainActor.run {
            isSigningIn = true
            errorMessage = nil
        }
        
        defer {
            Task { @MainActor in
                isSigningIn = false
            }
        }
        
        do {
            // Check if Google Sign In is properly configured
            guard GIDSignIn.sharedInstance.configuration != nil else {
                await MainActor.run {
                    errorMessage = "Google Sign In not properly configured. Ensure GIDConfiguration is set."
                }
                return false
            }
            
            // Get the root view controller
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                await MainActor.run {
                    errorMessage = "Unable to find root view controller"
                }
                return false
            }
            
            // Start Google Sign In flow
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            
            let user = result.user
            
            guard let idToken = user.idToken?.tokenString else {
                await MainActor.run {
                    errorMessage = "Failed to get Google ID token"
                }
                return false
            }
            
            let accessToken = user.accessToken.tokenString
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
            
            // Sign in with Firebase
            _ = try await Auth.auth().signIn(with: credential)
            
            await MainActor.run {
                isAuthenticated = true
            }
            
            return true
            
        } catch {
            await MainActor.run {
                if let gidError = error as? GIDSignInError {
                    switch gidError.code {
                    case .canceled:
                        errorMessage = "Google Sign In was canceled"
                    default:
                        errorMessage = "Google Sign In failed: \(error.localizedDescription)"
                    }
                } else {
                    errorMessage = "Google Sign In failed: \(error.localizedDescription)"
                }
            }
            return false
        }
    }
    
    // MARK: - Apple Sign In
    
    func signInWithApple() async -> Bool {
        await MainActor.run {
            isSigningIn = true
            errorMessage = nil
        }
        
        defer {
            Task { @MainActor in
                isSigningIn = false
            }
        }
        
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        
        return await withCheckedContinuation { continuation in
            // Store continuation for later use
            self.authContinuation = continuation
            authorizationController.performRequests()
        }
    }
    
    // MARK: - Sign Out
    
    func signOut() async -> Bool {
        do {
            try Auth.auth().signOut()
            await MainActor.run {
                isAuthenticated = false
            }
            return true
        } catch {
            await MainActor.run {
                errorMessage = "Sign out failed: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    // MARK: - Helper Methods
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        
        return String(nonce)
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
    
    // MARK: - Apple Sign In Continuation
    
    private var authContinuation: CheckedContinuation<Bool, Never>?
}

// MARK: - ASAuthorizationControllerDelegate

extension SimpleAuthenticationService: ASAuthorizationControllerDelegate {
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task {
            do {
                if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                    guard let nonce = currentNonce else {
                        await MainActor.run {
                            errorMessage = "Invalid state: A login callback was received, but no login request was sent."
                        }
                        authContinuation?.resume(returning: false)
                        return
                    }
                    
                    guard let appleIDToken = appleIDCredential.identityToken else {
                        await MainActor.run {
                            errorMessage = "Unable to fetch identity token"
                        }
                        authContinuation?.resume(returning: false)
                        return
                    }
                    
                    guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                        await MainActor.run {
                            errorMessage = "Unable to serialize token string from data"
                        }
                        authContinuation?.resume(returning: false)
                        return
                    }
                    
                    let credential = OAuthProvider.appleCredential(withIDToken: idTokenString,
                                                                   rawNonce: nonce,
                                                                   fullName: appleIDCredential.fullName)
                    
                    _ = try await Auth.auth().signIn(with: credential)
                    
                    await MainActor.run {
                        isAuthenticated = true
                    }
                    
                    authContinuation?.resume(returning: true)
                } else {
                    await MainActor.run {
                        errorMessage = "Unexpected authorization type"
                    }
                    authContinuation?.resume(returning: false)
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Firebase authentication failed: \(error.localizedDescription)"
                }
                authContinuation?.resume(returning: false)
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            errorMessage = "Apple Sign In failed: \(error.localizedDescription)"
        }
        authContinuation?.resume(returning: false)
    }
    
    // MARK: - ASAuthorizationControllerPresentationContextProviding
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("No window found for Apple Sign In presentation")
        }
        return window
    }
}
