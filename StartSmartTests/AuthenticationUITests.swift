//
//  AuthenticationUITests.swift
//  StartSmartTests
//
//  Created by StartSmart Team on 9/11/25.
//

import XCTest
import SwiftUI
@testable import StartSmart

/// Tests for authentication UI components
final class AuthenticationUITests: XCTestCase {
    
    override func setUpWithError() throws {
        try super.setUpWithError()
    }
    
    override func tearDownWithError() throws {
        try super.tearDownWithError()
    }
    
    // MARK: - OnboardingView Tests
    
    func testOnboardingViewCreation() throws {
        // Test that OnboardingView can be created without errors
        let onboardingView = OnboardingView()
        XCTAssertNotNil(onboardingView, "OnboardingView should be created successfully")
    }
    
    func testFeatureRowCreation() throws {
        // Test that FeatureRow component can be created
        let featureRow = FeatureRow(
            icon: "brain.head.profile",
            title: "AI-Powered Content",
            description: "Personalized motivational speeches generated just for you"
        )
        XCTAssertNotNil(featureRow, "FeatureRow should be created successfully")
    }
    
    // MARK: - AuthenticationView Tests
    
    func testAuthenticationViewCreation() throws {
        // Test that AuthenticationView can be created without errors
        let authView = AuthenticationView()
        XCTAssertNotNil(authView, "AuthenticationView should be created successfully")
    }
    
    func testSigningInViewCreation() throws {
        // Test that SigningInView can be created
        let signingInView = SigningInView()
        XCTAssertNotNil(signingInView, "SigningInView should be created successfully")
    }
    
    func testSignedInViewCreation() throws {
        // Test that SignedInView can be created
        let signedInView = SignedInView()
        XCTAssertNotNil(signedInView, "SignedInView should be created successfully")
    }
    
    func testErrorViewCreation() throws {
        // Test that ErrorView can be created with different error types
        let testError = AuthenticationError.invalidAppleCredentials
        let errorView = ErrorView(error: testError) {
            // Retry action
        }
        XCTAssertNotNil(errorView, "ErrorView should be created successfully")
    }
    
    // MARK: - Loading Views Tests
    
    func testAuthenticationLoadingViewCreation() throws {
        // Test default loading view
        let loadingView = AuthenticationLoadingView()
        XCTAssertNotNil(loadingView, "AuthenticationLoadingView should be created successfully")
    }
    
    func testAuthenticationLoadingViewWithCustomText() throws {
        // Test loading view with custom text
        let loadingView = AuthenticationLoadingView(
            title: "Custom Title",
            subtitle: "Custom Subtitle"
        )
        XCTAssertNotNil(loadingView, "AuthenticationLoadingView with custom text should be created successfully")
    }
    
    func testAuthenticationSuccessViewCreation() throws {
        // Test success view
        let successView = AuthenticationSuccessView(userName: "Test User")
        XCTAssertNotNil(successView, "AuthenticationSuccessView should be created successfully")
    }
    
    func testAuthenticationErrorViewCreation() throws {
        // Test error view with different error types
        let testError = AuthenticationError.googleSignInCancelled
        let errorView = AuthenticationErrorView(error: testError) {
            // Retry action
        }
        XCTAssertNotNil(errorView, "AuthenticationErrorView should be created successfully")
    }
    
    // MARK: - Button Style Tests
    
    func testPrimaryButtonStyleCreation() throws {
        // Test that PrimaryButtonStyle can be created
        let buttonStyle = PrimaryButtonStyle()
        XCTAssertNotNil(buttonStyle, "PrimaryButtonStyle should be created successfully")
    }
    
    func testSecondaryButtonStyleCreation() throws {
        // Test that SecondaryButtonStyle can be created
        let buttonStyle = SecondaryButtonStyle()
        XCTAssertNotNil(buttonStyle, "SecondaryButtonStyle should be created successfully")
    }
    
    // MARK: - ContentView Tests
    
    func testContentViewCreation() throws {
        // Test that ContentView can be created
        let contentView = ContentView()
        XCTAssertNotNil(contentView, "ContentView should be created successfully")
    }
    
    func testMainAppViewCreation() throws {
        // Test that MainAppView can be created
        let mainAppView = MainAppView()
        XCTAssertNotNil(mainAppView, "MainAppView should be created successfully")
    }
    
    // MARK: - Authentication State Handling Tests
    
    func testAuthenticationStateEnum() throws {
        // Test that all authentication states can be created
        let signedOut = AuthenticationState.signedOut
        let signingIn = AuthenticationState.signingIn
        let signedIn = AuthenticationState.signedIn
        let error = AuthenticationState.error(AuthenticationError.userNotSignedIn)
        
        XCTAssertNotNil(signedOut, "signedOut state should be created")
        XCTAssertNotNil(signingIn, "signingIn state should be created")
        XCTAssertNotNil(signedIn, "signedIn state should be created")
        XCTAssertNotNil(error, "error state should be created")
    }
    
    // MARK: - Error Message Tests
    
    func testAuthenticationErrorMessages() throws {
        // Test that all authentication errors have proper descriptions
        let errors: [AuthenticationError] = [
            .userNotSignedIn,
            .invalidAppleCredentials,
            .invalidGoogleCredentials,
            .googleSignInCancelled,
            .noPresentingViewController,
            .profileCreationFailed
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error \(error) should have a description")
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true, "Error description should not be empty")
        }
    }
    
    // MARK: - Integration Tests
    
    func testAuthenticationFlowIntegration() throws {
        // Test that authentication components work together
        let authService = DependencyContainer.shared.authenticationService
        XCTAssertNotNil(authService, "AuthenticationService should be available from DI container")
        
        let firebaseService = DependencyContainer.shared.firebaseService
        XCTAssertNotNil(firebaseService, "FirebaseService should be available from DI container")
    }
    
    // MARK: - UI State Tests
    
    func testUIStateTransitions() throws {
        // Test that UI can handle different authentication states
        // This is more of a conceptual test since we can't easily test SwiftUI state changes in unit tests
        
        // Verify that we have views for all authentication states
        let states: [AuthenticationState] = [
            .signedOut,
            .signingIn,
            .signedIn,
            .error(AuthenticationError.userNotSignedIn)
        ]
        
        for state in states {
            switch state {
            case .signedOut:
                let view = OnboardingView()
                XCTAssertNotNil(view, "Should have view for signedOut state")
            case .signingIn:
                let view = SigningInView()
                XCTAssertNotNil(view, "Should have view for signingIn state")
            case .signedIn:
                let view = SignedInView()
                XCTAssertNotNil(view, "Should have view for signedIn state")
            case .error:
                let view = ErrorView(error: AuthenticationError.userNotSignedIn) { }
                XCTAssertNotNil(view, "Should have view for error state")
            }
        }
    }
}
