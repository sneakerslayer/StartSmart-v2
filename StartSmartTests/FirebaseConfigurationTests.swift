//
//  FirebaseConfigurationTests.swift
//  StartSmartTests
//
//  Created by StartSmart Team on 9/11/25.
//

import XCTest
@testable import StartSmart
import FirebaseCore

/// Tests for Firebase configuration and integration
final class FirebaseConfigurationTests: XCTestCase {
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        // Configure Firebase for testing if not already configured
        if FirebaseApp.app() == nil {
            FirebaseConfiguration.configure()
        }
    }
    
    override func tearDownWithError() throws {
        try super.tearDownWithError()
    }
    
    // MARK: - Configuration Tests
    
    func testFirebaseConfigurationExists() throws {
        // Test that GoogleService-Info.plist exists and is valid
        let bundle = Bundle.main
        let path = bundle.path(forResource: "GoogleService-Info", ofType: "plist")
        
        XCTAssertNotNil(path, "GoogleService-Info.plist not found in main bundle")
        
        if let path = path {
            let plist = NSDictionary(contentsOfFile: path)
            XCTAssertNotNil(plist, "GoogleService-Info.plist is not valid")
            
            // Check required keys
            XCTAssertNotNil(plist?["CLIENT_ID"], "CLIENT_ID missing from GoogleService-Info.plist")
            XCTAssertNotNil(plist?["BUNDLE_ID"], "BUNDLE_ID missing from GoogleService-Info.plist")
            XCTAssertNotNil(plist?["PROJECT_ID"], "PROJECT_ID missing from GoogleService-Info.plist")
            
            // Verify bundle ID matches
            let bundleId = plist?["BUNDLE_ID"] as? String
            XCTAssertEqual(bundleId, "com.startsmart.mobile", "Bundle ID should match com.startsmart.mobile")
        }
    }
    
    func testFirebaseAppConfiguration() throws {
        // Test that Firebase is properly configured
        let app = FirebaseApp.app()
        XCTAssertNotNil(app, "Firebase app should be configured")
        
        if let app = app {
            XCTAssertNotNil(app.options.projectID, "Firebase project ID should be set")
            XCTAssertNotNil(app.options.bundleID, "Firebase bundle ID should be set")
            XCTAssertEqual(app.options.bundleID, "com.startsmart.mobile", "Bundle ID should match")
        }
    }
    
    func testFirebaseServicesAvailable() throws {
        // Test that required Firebase services are available
        
        // Test Auth
        let auth = Auth.auth()
        XCTAssertNotNil(auth, "Firebase Auth should be available")
        
        // Test Firestore
        let firestore = Firestore.firestore()
        XCTAssertNotNil(firestore, "Firestore should be available")
        
        // Test Storage
        let storage = Storage.storage()
        XCTAssertNotNil(storage, "Firebase Storage should be available")
    }
    
    // MARK: - Mock Firebase Service Tests
    
    func testFirebaseServiceCreation() throws {
        // Test that FirebaseService can be created without errors
        let firebaseService = FirebaseService()
        XCTAssertNotNil(firebaseService, "FirebaseService should be created successfully")
        XCTAssertFalse(firebaseService.isUserSignedIn, "User should not be signed in initially")
        XCTAssertNil(firebaseService.currentUser, "Current user should be nil initially")
    }
    
    func testAuthenticationServiceCreation() throws {
        // Test that AuthenticationService can be created without errors
        let authService = AuthenticationService()
        XCTAssertNotNil(authService, "AuthenticationService should be created successfully")
        XCTAssertFalse(authService.isAuthenticated, "User should not be authenticated initially")
        XCTAssertNil(authService.currentUser, "Current user should be nil initially")
    }
    
    func testDependencyInjectionSetup() throws {
        // Test that Firebase services are properly registered in DI container
        let container = DependencyContainer.shared
        
        // This will throw if services are not properly registered
        let firebaseService: FirebaseServiceProtocol = container.resolve()
        XCTAssertNotNil(firebaseService, "FirebaseService should be resolved from DI container")
        
        let authService: AuthenticationServiceProtocol = container.resolve()
        XCTAssertNotNil(authService, "AuthenticationService should be resolved from DI container")
    }
    
    // MARK: - Configuration Helper Tests
    
    func testConfigurationHelper() throws {
        // Test the Firebase configuration helper
        // This test ensures that calling configure multiple times doesn't crash
        XCTAssertNoThrow(FirebaseConfiguration.configure(), "Firebase configuration should not throw")
        XCTAssertNoThrow(FirebaseConfiguration.configure(), "Multiple Firebase configurations should not throw")
    }
    
    // MARK: - Bundle ID Validation
    
    func testBundleIdConsistency() throws {
        // Test that bundle ID is consistent across configuration
        let mainBundleId = Bundle.main.bundleIdentifier
        XCTAssertEqual(mainBundleId, "com.startsmart.mobile", "Main bundle identifier should be com.startsmart.mobile")
        
        if let app = FirebaseApp.app() {
            XCTAssertEqual(app.options.bundleID, mainBundleId, "Firebase bundle ID should match main bundle ID")
        }
    }
}

// MARK: - Mock Firebase Service for Testing

/// Mock Firebase service for testing when real Firebase is not available
class MockFirebaseService: FirebaseServiceProtocol {
    var isUserSignedIn: Bool = false
    var currentUser: User?
    
    func signInWithApple(idToken: String, nonce: String) async throws -> User {
        throw FirebaseServiceError.configurationMissing
    }
    
    func signInWithGoogle(idToken: String, accessToken: String) async throws -> User {
        throw FirebaseServiceError.configurationMissing
    }
    
    func signOut() throws {
        isUserSignedIn = false
        currentUser = nil
    }
    
    func saveUserProfile(_ userProfile: UserProfile) async throws {
        throw FirebaseServiceError.configurationMissing
    }
    
    func loadUserProfile(userId: String) async throws -> UserProfile? {
        return nil
    }
    
    func saveAlarm(_ alarm: Alarm, userId: String) async throws {
        throw FirebaseServiceError.configurationMissing
    }
    
    func loadUserAlarms(userId: String) async throws -> [Alarm] {
        return []
    }
    
    func deleteAlarm(alarmId: String, userId: String) async throws {
        throw FirebaseServiceError.configurationMissing
    }
    
    func uploadAudioContent(data: Data, fileName: String) async throws -> URL {
        throw FirebaseServiceError.configurationMissing
    }
    
    func downloadAudioContent(url: URL) async throws -> Data {
        throw FirebaseServiceError.configurationMissing
    }
}

// MARK: - Test Configuration

extension FirebaseConfigurationTests {
    
    /// Configure mock services for testing when Firebase is not available
    func setupMockServices() {
        let container = DependencyContainer.shared
        let mockFirebaseService = MockFirebaseService()
        container.register(mockFirebaseService, for: FirebaseServiceProtocol.self)
    }
}
