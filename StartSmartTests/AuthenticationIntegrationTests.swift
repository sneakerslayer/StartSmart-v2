//
//  AuthenticationIntegrationTests.swift
//  StartSmartTests
//
//  Created by StartSmart Team on 9/11/25.
//

import XCTest
@testable import StartSmart
import FirebaseCore
import FirebaseAuth

/// Integration tests for authentication flows with real Firebase
final class AuthenticationIntegrationTests: XCTestCase {
    
    var authService: AuthenticationService!
    var firebaseService: FirebaseService!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Configure Firebase for testing
        if FirebaseApp.app() == nil {
            FirebaseConfiguration.configure()
        }
        
        // Initialize services
        authService = AuthenticationService()
        firebaseService = FirebaseService()
        
        // Ensure we start with a clean state
        try? Auth.auth().signOut()
    }
    
    override func tearDownWithError() throws {
        // Clean up after tests
        try? Auth.auth().signOut()
        authService = nil
        firebaseService = nil
        
        try super.tearDownWithError()
    }
    
    // MARK: - Firebase Configuration Tests
    
    func testFirebaseConfiguration() throws {
        // Test that Firebase is properly configured
        let app = FirebaseApp.app()
        XCTAssertNotNil(app, "Firebase app should be configured")
        
        if let app = app {
            XCTAssertEqual(app.options.bundleID, "com.startsmart.mobile", "Bundle ID should match")
            XCTAssertNotNil(app.options.projectID, "Project ID should be set")
            XCTAssertNotNil(app.options.clientID, "Client ID should be set for Google Sign In")
        }
    }
    
    func testFirebaseServicesAvailable() throws {
        // Test that all required Firebase services are available
        XCTAssertNoThrow(Auth.auth(), "Firebase Auth should be available")
        XCTAssertNoThrow(Firestore.firestore(), "Firestore should be available")
        XCTAssertNoThrow(Storage.storage(), "Firebase Storage should be available")
    }
    
    // MARK: - Authentication Service Tests
    
    func testAuthenticationServiceInitialization() throws {
        // Test that AuthenticationService initializes correctly
        XCTAssertNotNil(authService, "AuthenticationService should initialize")
        XCTAssertFalse(authService.isAuthenticated, "Should not be authenticated initially")
        XCTAssertNil(authService.currentUser, "Should have no current user initially")
    }
    
    func testFirebaseServiceInitialization() throws {
        // Test that FirebaseService initializes correctly
        XCTAssertNotNil(firebaseService, "FirebaseService should initialize")
        XCTAssertFalse(firebaseService.isUserSignedIn, "Should not be signed in initially")
        XCTAssertNil(firebaseService.currentUser, "Should have no current user initially")
    }
    
    // MARK: - Authentication State Management Tests
    
    func testAuthenticationStateUpdate() async throws {
        // Test that authentication state updates correctly
        await authService.updateAuthenticationState()
        
        // Should remain unauthenticated if no user is signed in
        XCTAssertFalse(authService.isAuthenticated, "Should remain unauthenticated")
        XCTAssertEqual(authService.authenticationState, .signedOut, "State should be signedOut")
    }
    
    // MARK: - Error Handling Tests
    
    func testSignOutWhenNotSignedIn() async throws {
        // Test that signing out when not signed in doesn't crash
        XCTAssertNoThrow(try await authService.signOut(), "Sign out should not throw when not signed in")
    }
    
    func testInvalidCredentialsHandling() async throws {
        // Test that invalid credentials are handled gracefully
        // Note: We can't easily test this without actual invalid credentials
        // This test verifies that the error handling structure is in place
        
        do {
            // This should fail since we don't have valid Apple credentials
            _ = try await firebaseService.signInWithApple(idToken: "invalid", nonce: "invalid")
            XCTFail("Should have thrown an error with invalid credentials")
        } catch {
            // Expected to fail - verify error is handled appropriately
            XCTAssertNotNil(error, "Should receive an error for invalid credentials")
        }
    }
    
    // MARK: - User Profile Tests
    
    func testUserProfileStructure() throws {
        // Test that UserProfile can be created and encoded/decoded
        let userProfile = UserProfile(
            id: "test-id",
            email: "test@example.com",
            displayName: "Test User",
            createdAt: Date(),
            subscriptionTier: .free,
            preferences: UserPreferences()
        )
        
        XCTAssertEqual(userProfile.id, "test-id")
        XCTAssertEqual(userProfile.email, "test@example.com")
        XCTAssertEqual(userProfile.displayName, "Test User")
        XCTAssertEqual(userProfile.subscriptionTier, .free)
        
        // Test JSON encoding/decoding
        do {
            let data = try userProfile.toDictionary()
            XCTAssertNotNil(data, "Should be able to convert to dictionary")
            
            let decodedProfile = try UserProfile.fromDictionary(data)
            XCTAssertEqual(decodedProfile.id, userProfile.id)
            XCTAssertEqual(decodedProfile.email, userProfile.email)
            XCTAssertEqual(decodedProfile.displayName, userProfile.displayName)
        } catch {
            XCTFail("UserProfile encoding/decoding should not throw: \(error)")
        }
    }
    
    // MARK: - Network Connectivity Tests
    
    func testFirebaseConnectivity() async throws {
        // Test basic Firebase connectivity
        let firestore = Firestore.firestore()
        
        do {
            // Try to read from a public collection (this might fail if rules are restrictive)
            // This is just to test basic connectivity
            let _ = try await firestore.collection("test").limit(to: 1).getDocuments()
        } catch {
            // Connection errors are expected if offline or if security rules prevent access
            // We just want to verify that we get a proper Firebase error, not a configuration error
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, "FIRFirestoreErrorDomain", "Should be a proper Firestore error")
        }
    }
    
    // MARK: - Dependency Injection Tests
    
    func testDependencyInjectionIntegration() throws {
        // Test that authentication services are properly registered in DI container
        let container = DependencyContainer.shared
        
        let resolvedFirebaseService: FirebaseServiceProtocol = container.resolve()
        XCTAssertNotNil(resolvedFirebaseService, "Should resolve FirebaseService from DI")
        
        let resolvedAuthService: AuthenticationServiceProtocol = container.resolve()
        XCTAssertNotNil(resolvedAuthService, "Should resolve AuthenticationService from DI")
    }
    
    // MARK: - Authentication Flow Simulation Tests
    
    func testSignInFlowStructure() async throws {
        // Test the structure of sign-in flows without actual authentication
        // This verifies that the methods exist and can be called
        
        // Test Apple Sign In structure
        do {
            // This will fail but should not crash
            _ = try await authService.signInWithApple()
            XCTFail("Should fail without proper Apple credentials")
        } catch {
            // Expected to fail - verify it's the right type of error
            XCTAssertTrue(error is AuthenticationError || error is NSError, "Should be an authentication error")
        }
        
        // Test Google Sign In structure
        do {
            // This will fail but should not crash
            _ = try await authService.signInWithGoogle()
            XCTFail("Should fail without proper setup")
        } catch {
            // Expected to fail - verify it's the right type of error
            XCTAssertTrue(error is AuthenticationError || error is NSError, "Should be an authentication error")
        }
    }
    
    // MARK: - Performance Tests
    
    func testAuthenticationServicePerformance() throws {
        // Test that authentication service initialization is fast
        measure {
            let _ = AuthenticationService()
        }
    }
    
    func testFirebaseServicePerformance() throws {
        // Test that Firebase service initialization is fast
        measure {
            let _ = FirebaseService()
        }
    }
}

// MARK: - Manual Testing Guide Extension

extension AuthenticationIntegrationTests {
    
    /// Manual testing checklist for authentication flows
    /// This is printed to help with manual testing
    func testManualTestingGuide() throws {
        let guide = """
        
        🧪 MANUAL AUTHENTICATION TESTING GUIDE
        
        1. 🍎 APPLE SIGN IN TEST:
           - Run the app on device or simulator
           - Tap "Continue with Apple"
           - Complete Apple Sign In flow
           - Verify: User profile created, welcome screen shows
           
        2. 🔍 GOOGLE SIGN IN TEST:
           - Run the app on device or simulator  
           - Tap "Continue with Google"
           - Complete Google Sign In flow
           - Verify: User profile created, welcome screen shows
           
        3. 🔄 STATE PERSISTENCE TEST:
           - Sign in with either provider
           - Force close the app
           - Reopen the app
           - Verify: User remains signed in
           
        4. 🚪 SIGN OUT TEST:
           - While signed in, tap "Sign Out"
           - Verify: Returns to onboarding screen
           - Verify: Firebase auth state cleared
           
        5. 🔥 FIREBASE CONSOLE VERIFICATION:
           - Check Firebase Console → Authentication
           - Verify: User appears in user list
           - Check Firestore → users collection
           - Verify: User profile document created
           
        6. 🚨 ERROR HANDLING TEST:
           - Try signing in without internet
           - Cancel sign-in mid-flow
           - Verify: Appropriate error messages shown
           
        SUCCESS CRITERIA:
        ✅ All sign-in methods work smoothly
        ✅ User profiles persist in Firestore
        ✅ Authentication state maintained across app restarts
        ✅ Error messages are user-friendly
        ✅ No crashes or unexpected behavior
        
        """
        
        print(guide)
        XCTAssertTrue(true, "Manual testing guide printed")
    }
}
