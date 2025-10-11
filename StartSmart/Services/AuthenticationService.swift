//
//  AuthenticationService.swift
//  StartSmart
//
//  Created by StartSmart Team on 9/11/25.
//

import Foundation
import AuthenticationServices
import GoogleSignIn
import FirebaseAuth
import Combine

extension Notification.Name {
    static let authStateDidChange = Notification.Name("authStateDidChange")
}
import CryptoKit

// MARK: - Authentication Service Protocol

/// Protocol defining authentication operations
protocol AuthenticationServiceProtocol {
    var isAuthenticated: Bool { get }
    var currentUser: User? { get }
    
    func signInWithApple() async throws -> User
    func signInWithGoogle() async throws -> User
    func signOut() async throws
    func deleteAccount() async throws
}

// MARK: - Authentication Service Implementation

/// Service managing user authentication flows
@MainActor
class AuthenticationService: NSObject, @preconcurrency AuthenticationServiceProtocol, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: User?
    @Published var authenticationState: AuthenticationState = .signedOut
    
    // MARK: - Private Properties
    
    private let firebaseService: FirebaseServiceProtocol
    private let userViewModel: UserViewModel
    
    private var cancellables = Set<AnyCancellable>()
    private var currentNonce: String?
    
    // MARK: - Initialization
    
    init(firebaseService: FirebaseServiceProtocol, userViewModel: UserViewModel) {
        self.firebaseService = firebaseService
        self.userViewModel = userViewModel
        super.init()
        setupAuthenticationStateListener()
    }
    
    // MARK: - Authentication State Management
    
    private func setupAuthenticationStateListener() {
        // Listen to Firebase auth state changes
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                await self?.updateAuthenticationState()
            }
        }
        
        // Also listen to userViewModel changes
        userViewModel.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.updateAuthenticationState()
                }
            }
            .store(in: &cancellables)
        
        // Initial state update
        Task {
            await updateAuthenticationState()
        }
    }
    
    func updateAuthenticationState() async {
        isAuthenticated = firebaseService.isUserSignedIn
        
        if let firebaseUser = Auth.auth().currentUser {
            // Load user profile from Firebase
            do {
                currentUser = try await firebaseService.loadUserProfile(userId: firebaseUser.uid)
                authenticationState = .signedIn
            } catch {
                print("Failed to load user profile: \(error)")
                authenticationState = .error(error)
            }
        } else {
            currentUser = nil
            authenticationState = .signedOut
        }
    }
    
    // MARK: - Sign In with Apple
    
    func signInWithApple() async throws -> User {
        authenticationState = .signingIn
        
        do {
            let nonce = randomNonceString()
            currentNonce = nonce
            
            let appleIDCredential = try await requestAppleAuthorization(nonce: sha256(nonce))
            
            guard let appleIDToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                throw AuthenticationError.invalidAppleCredentials
            }
            
            // Sign in with Firebase
            let firebaseUser = try await firebaseService.signInWithApple(
                idToken: idTokenString,
                nonce: nonce
            )
            
            // Load or create user profile
            let user = try await loadOrCreateUserProfile(
                firebaseUser: firebaseUser,
                appleCredential: appleIDCredential
            )
            
            await updateAuthenticationState()
            return user
            
        } catch {
            authenticationState = .error(error)
            throw error
        }
    }
    
    private func requestAppleAuthorization(nonce: String) async throws -> ASAuthorizationAppleIDCredential {
        return try await withCheckedThrowingContinuation { continuation in
            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = nonce
            
            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            
            let delegate = AppleSignInDelegate { result in
                continuation.resume(with: result)
            }
            
            authorizationController.delegate = delegate
            authorizationController.performRequests()
        }
    }
    
    // MARK: - Sign In with Google
    
    func signInWithGoogle() async throws -> User {
        authenticationState = .signingIn
        
        do {
            guard let presentingViewController = await UIApplication.shared.windows.first?.rootViewController else {
                throw AuthenticationError.noPresentingViewController
            }
            
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
            
            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthenticationError.invalidGoogleCredentials
            }
            
            let accessToken = result.user.accessToken.tokenString
            
            // Sign in with Firebase
            let firebaseUser = try await firebaseService.signInWithGoogle(
                idToken: idToken,
                accessToken: accessToken
            )
            
            // Load or create user profile
            let user = try await loadOrCreateUserProfile(
                firebaseUser: firebaseUser,
                googleUser: result.user
            )
            
            await updateAuthenticationState()
            return user
            
        } catch {
            authenticationState = .error(error)
            throw error
        }
    }
    
    // MARK: - Sign Out
    
    func signOut() async throws {
        do {
            try firebaseService.signOut()
            GIDSignIn.sharedInstance.signOut()
            
            await updateAuthenticationState()
            
        } catch {
            authenticationState = .error(error)
            throw error
        }
    }
    
    // MARK: - Delete Account
    
    func deleteAccount() async throws {
        guard let user = firebaseService.currentUser else {
            throw AuthenticationError.userNotSignedIn
        }
        
        do {
            // Delete user data from Firestore
            // This would include alarms, preferences, etc.
            
            // Delete Firebase Auth user
            try await firebaseService.deleteUser()
            
            await updateAuthenticationState()
            
        } catch {
            authenticationState = .error(error)
            throw error
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadOrCreateUserProfile(
        firebaseUser: User,
        appleCredential: ASAuthorizationAppleIDCredential? = nil,
        googleUser: GIDGoogleUser? = nil
    ) async throws -> User {
        
        // Try to load existing profile
        if let existingProfile = try await firebaseService.loadUserProfile(userId: firebaseUser.id.uuidString) {
            return existingProfile
        }
        
        // Create new profile
        let displayName: String
        if let appleCredential = appleCredential {
            displayName = [appleCredential.fullName?.givenName, appleCredential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
                .isEmpty ? "User" : [appleCredential.fullName?.givenName, appleCredential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
        } else if let googleUser = googleUser {
            displayName = googleUser.profile?.name ?? "User"
        } else {
            displayName = firebaseUser.displayName ?? "User"
        }
        
        let user = User(
            email: firebaseUser.email,
            displayName: displayName,
            preferences: UserPreferences(),
            subscription: .free
        )
        
        try await firebaseService.saveUserProfile(user)
        return user
    }
    
    // MARK: - Apple Sign In Helpers
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
}

// MARK: - Apple Sign In Delegate

private class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate {
    private let completion: (Result<ASAuthorizationAppleIDCredential, Error>) -> Void
    
    init(completion: @escaping (Result<ASAuthorizationAppleIDCredential, Error>) -> Void) {
        self.completion = completion
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            completion(.success(appleIDCredential))
        } else {
            completion(.failure(AuthenticationError.invalidAppleCredentials))
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completion(.failure(error))
    }
}

// MARK: - Authentication State

enum AuthenticationState {
    case signedOut
    case signingIn
    case signedIn
    case error(Error)
}

// MARK: - Authentication Errors

enum AuthenticationError: LocalizedError {
    case userNotSignedIn
    case invalidAppleCredentials
    case invalidGoogleCredentials
    case googleSignInCancelled
    case noPresentingViewController
    case profileCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .userNotSignedIn:
            return "User is not signed in"
        case .invalidAppleCredentials:
            return "Invalid Apple Sign In credentials"
        case .invalidGoogleCredentials:
            return "Invalid Google Sign In credentials"
        case .googleSignInCancelled:
            return "Google Sign In was cancelled"
        case .noPresentingViewController:
            return "No presenting view controller available"
        case .profileCreationFailed:
            return "Failed to create user profile"
        }
    }
}
