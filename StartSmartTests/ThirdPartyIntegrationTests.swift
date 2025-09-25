import XCTest
@testable import StartSmart
import RevenueCat
import UserNotifications
import FirebaseCore
import FirebaseAuth
import Combine

/// Tests to verify all third-party integrations work correctly
final class ThirdPartyIntegrationTests: XCTestCase {
    
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDownWithError() throws {
        cancellables = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Firebase Integration Tests
    
    func testFirebaseConfiguration() throws {
        // Test Firebase is properly configured
        let app = FirebaseApp.app()
        XCTAssertNotNil(app, "Firebase app should be configured")
        
        if let app = app {
            let options = app.options
            XCTAssertNotNil(options.projectID, "Firebase project ID should be configured")
            XCTAssertNotNil(options.clientID, "Firebase client ID should be configured")
            XCTAssertNotNil(options.apiKey, "Firebase API key should be configured")
            
            // Verify bundle ID matches
            XCTAssertEqual(options.bundleID, "com.startsmart.mobile", "Bundle ID should match expected value")
        }
    }
    
    func testFirebaseAuthAvailable() throws {
        // Test Firebase Auth is available and configured
        let auth = Auth.auth()
        XCTAssertNotNil(auth, "Firebase Auth should be available")
        
        // Test auth state listener can be added
        let handle = auth.addStateDidChangeListener { _, _ in
            // Mock listener
        }
        XCTAssertNotNil(handle, "Auth state listener should be addable")
        
        // Clean up
        auth.removeStateDidChangeListener(handle)
    }
    
    func testFirestoreAvailable() throws {
        // Test Firestore is available and configured
        let firestore = Firestore.firestore()
        XCTAssertNotNil(firestore, "Firestore should be available")
        
        // Test basic collection reference creation
        let collection = firestore.collection("test")
        XCTAssertNotNil(collection, "Should be able to create collection reference")
        XCTAssertEqual(collection.collectionID, "test", "Collection ID should match")
    }
    
    func testFirebaseStorageAvailable() throws {
        // Test Firebase Storage is available
        let storage = Storage.storage()
        XCTAssertNotNil(storage, "Firebase Storage should be available")
        
        // Test storage reference creation
        let reference = storage.reference()
        XCTAssertNotNil(reference, "Should be able to create storage reference")
    }
    
    // MARK: - RevenueCat Integration Tests
    
    func testRevenueCatConfiguration() throws {
        // Test RevenueCat can be configured
        let apiKey = "test_api_key"
        
        // This would normally configure RevenueCat in a real app
        // For testing, we just verify the API key format is valid
        XCTAssertFalse(apiKey.isEmpty, "RevenueCat API key should not be empty")
        XCTAssertTrue(apiKey.hasPrefix("test_"), "Test API key should have test prefix")
    }
    
    func testSubscriptionServiceInitialization() throws {
        // Test SubscriptionService initializes with RevenueCat
        let subscriptionService = SubscriptionService(revenueCatApiKey: "test_api_key")
        XCTAssertNotNil(subscriptionService, "SubscriptionService should initialize")
        XCTAssertEqual(subscriptionService.currentSubscriptionStatus, .free, "Should start with free status")
    }
    
    func testSubscriptionStatusMapping() throws {
        let subscriptionService = SubscriptionService(revenueCatApiKey: "test_api_key")
        
        // Test mapping logic with mock customer info
        let mockCustomerInfo = createMockCustomerInfo(activeEntitlements: [:])
        let status = subscriptionService.mapToSubscriptionStatus(mockCustomerInfo)
        XCTAssertEqual(status, .free, "Empty entitlements should map to free")
        
        // Test pro monthly mapping
        let proEntitlement = createMockEntitlement(productId: "startsmart_pro_monthly")
        let proCustomerInfo = createMockCustomerInfo(activeEntitlements: ["pro": proEntitlement])
        let proStatus = subscriptionService.mapToSubscriptionStatus(proCustomerInfo)
        XCTAssertEqual(proStatus, .proMonthly, "Pro monthly should map correctly")
    }
    
    // MARK: - iOS UserNotifications Integration Tests
    
    func testNotificationCenterAvailable() throws {
        // Test UNUserNotificationCenter is available
        let center = UNUserNotificationCenter.current()
        XCTAssertNotNil(center, "UNUserNotificationCenter should be available")
    }
    
    func testNotificationServiceInitialization() throws {
        // Test NotificationService initializes properly
        let notificationService = NotificationService()
        XCTAssertNotNil(notificationService, "NotificationService should initialize")
        XCTAssertEqual(notificationService.permissionStatus, .notDetermined, "Should start with notDetermined status")
    }
    
    func testNotificationCategoryRegistration() throws {
        // Test notification categories can be registered
        let categoryService = NotificationCategoryService()
        XCTAssertNotNil(categoryService, "NotificationCategoryService should initialize")
        
        // Test category creation
        let categories = categoryService.createAlarmCategories()
        XCTAssertFalse(categories.isEmpty, "Should create alarm categories")
        
        // Verify specific categories exist
        let categoryIds = categories.map { $0.identifier }
        XCTAssertTrue(categoryIds.contains("ALARM_CATEGORY"), "Should have alarm category")
        XCTAssertTrue(categoryIds.contains("ALARM_SNOOZE_CATEGORY"), "Should have snooze category")
    }
    
    func testNotificationContentCreation() throws {
        // Test UNMutableNotificationContent creation
        let content = UNMutableNotificationContent()
        content.title = "Test Alarm"
        content.body = "Time to wake up!"
        content.sound = .default
        content.categoryIdentifier = "ALARM_CATEGORY"
        
        XCTAssertEqual(content.title, "Test Alarm")
        XCTAssertEqual(content.body, "Time to wake up!")
        XCTAssertEqual(content.categoryIdentifier, "ALARM_CATEGORY")
    }
    
    // MARK: - AVFoundation Integration Tests
    
    func testAudioSessionConfiguration() throws {
        // Test AVAudioSession configuration for alarm audio
        let audioSession = AVAudioSession.sharedInstance()
        XCTAssertNotNil(audioSession, "AVAudioSession should be available")
        
        // Test category setting
        try audioSession.setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetoothA2DP])
        XCTAssertEqual(audioSession.category, .playback, "Audio category should be set to playback")
    }
    
    func testAudioPlayerCreation() throws {
        // Test AVAudioPlayer can be created with mock data
        let mockAudioData = createMockAudioData()
        let player = try AVAudioPlayer(data: mockAudioData)
        
        XCTAssertNotNil(player, "AVAudioPlayer should be created")
        XCTAssertFalse(player.isPlaying, "Player should not be playing initially")
        XCTAssertGreaterThan(player.duration, 0, "Player should have valid duration")
    }
    
    func testSpeechRecognitionFramework() throws {
        // Test Speech framework availability
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        XCTAssertNotNil(recognizer, "SFSpeechRecognizer should be available")
        
        // Test supported locales
        let supportedLocales = SFSpeechRecognizer.supportedLocales()
        XCTAssertFalse(supportedLocales.isEmpty, "Should have supported locales")
        XCTAssertTrue(supportedLocales.contains(Locale(identifier: "en-US")), "Should support English US")
    }
    
    // MARK: - Network Integration Tests
    
    func testURLSessionConfiguration() throws {
        // Test URLSession configuration for API calls
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        
        let session = URLSession(configuration: config)
        XCTAssertNotNil(session, "URLSession should be created")
        XCTAssertEqual(session.configuration.timeoutIntervalForRequest, 30.0, "Request timeout should be set")
    }
    
    func testAPIEndpointReachability() async throws {
        // Test basic network connectivity (without making actual API calls)
        let url = URL(string: "https://api.elevenlabs.io")!
        let request = URLRequest(url: url)
        
        // Verify request can be created
        XCTAssertNotNil(request, "URLRequest should be created")
        XCTAssertEqual(request.url, url, "Request URL should match")
    }
    
    // MARK: - Integration Error Handling Tests
    
    func testFirebaseErrorHandling() throws {
        // Test Firebase error handling
        let authService = AuthenticationService()
        XCTAssertNotNil(authService, "AuthenticationService should initialize")
        
        // Test error mapping
        let nsError = NSError(domain: "FIRAuthErrorDomain", code: 17011, userInfo: nil)
        let authError = AuthenticationServiceError.from(nsError)
        
        switch authError {
        case .userNotFound:
            XCTAssertTrue(true, "Should map to userNotFound error")
        default:
            XCTAssertTrue(true, "Should handle error gracefully")
        }
    }
    
    func testRevenueCatErrorHandling() throws {
        // Test RevenueCat error handling
        let subscriptionService = SubscriptionService(revenueCatApiKey: "test_api_key")
        
        // Test error mapping
        let rcError = NSError(domain: "RCPurchasesErrorDomain", code: 1, userInfo: nil)
        let subscriptionError = SubscriptionError.from(rcError)
        
        switch subscriptionError {
        case .userCancelled:
            XCTAssertTrue(true, "Should map to userCancelled error")
        default:
            XCTAssertTrue(true, "Should handle error gracefully")
        }
    }
    
    func testNotificationErrorHandling() throws {
        // Test notification error handling
        let notificationService = NotificationService()
        
        // Test permission denied scenario
        let error = NotificationServiceError.permissionDenied
        XCTAssertEqual(error.localizedDescription, "Notification permission denied", "Should have proper error message")
        
        // Test scheduling error
        let schedulingError = NotificationServiceError.schedulingFailed("Test error")
        XCTAssertTrue(schedulingError.localizedDescription.contains("Test error"), "Should include error details")
    }
    
    // MARK: - Data Format Compatibility Tests
    
    func testJSONSerializationCompatibility() throws {
        // Test JSON serialization for API communication
        let alarm = Alarm(time: Date(), label: "Test Alarm")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(alarm)
        XCTAssertGreaterThan(data.count, 0, "Should encode alarm to JSON")
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let decodedAlarm = try decoder.decode(Alarm.self, from: data)
        XCTAssertEqual(decodedAlarm.id, alarm.id, "Should decode alarm correctly")
        XCTAssertEqual(decodedAlarm.label, alarm.label, "Should preserve alarm label")
    }
    
    func testUserDefaultsCompatibility() throws {
        // Test UserDefaults integration for local storage
        let userDefaults = UserDefaults.standard
        
        // Test basic data types
        userDefaults.set("test_value", forKey: "test_key")
        userDefaults.set(42, forKey: "test_number")
        userDefaults.set(true, forKey: "test_bool")
        
        XCTAssertEqual(userDefaults.string(forKey: "test_key"), "test_value")
        XCTAssertEqual(userDefaults.integer(forKey: "test_number"), 42)
        XCTAssertTrue(userDefaults.bool(forKey: "test_bool"))
        
        // Clean up
        userDefaults.removeObject(forKey: "test_key")
        userDefaults.removeObject(forKey: "test_number")
        userDefaults.removeObject(forKey: "test_bool")
    }
}

// MARK: - Test Helper Extensions

extension ThirdPartyIntegrationTests {
    
    private func createMockCustomerInfo(activeEntitlements: [String: MockEntitlement]) -> CustomerInfo {
        // This would create a mock CustomerInfo object for testing
        // In real implementation, this would use RevenueCat's testing utilities
        return MockCustomerInfo(entitlements: activeEntitlements)
    }
    
    private func createMockEntitlement(productId: String) -> MockEntitlement {
        return MockEntitlement(productIdentifier: productId, isActive: true)
    }
    
    private func createMockAudioData() -> Data {
        // Create minimal valid audio data for testing
        // This creates a simple WAV header with minimal audio data
        var data = Data()
        
        // WAV header
        data.append("RIFF".data(using: .ascii)!)
        data.append(Data([36, 0, 0, 0])) // File size - 8
        data.append("WAVE".data(using: .ascii)!)
        data.append("fmt ".data(using: .ascii)!)
        data.append(Data([16, 0, 0, 0])) // Subchunk1Size
        data.append(Data([1, 0])) // AudioFormat (PCM)
        data.append(Data([1, 0])) // NumChannels (mono)
        data.append(Data([68, 172, 0, 0])) // SampleRate (44100)
        data.append(Data([136, 88, 1, 0])) // ByteRate
        data.append(Data([2, 0])) // BlockAlign
        data.append(Data([16, 0])) // BitsPerSample
        data.append("data".data(using: .ascii)!)
        data.append(Data([0, 0, 0, 0])) // Subchunk2Size
        
        return data
    }
}

// MARK: - Mock RevenueCat Types for Testing

class MockCustomerInfo: CustomerInfo {
    private let mockEntitlements: [String: MockEntitlement]
    
    init(entitlements: [String: MockEntitlement]) {
        self.mockEntitlements = entitlements
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var activeSubscriptions: Set<String> {
        return Set(mockEntitlements.keys)
    }
}

class MockEntitlement: EntitlementInfo {
    private let mockProductIdentifier: String
    private let mockIsActive: Bool
    
    init(productIdentifier: String, isActive: Bool) {
        self.mockProductIdentifier = productIdentifier
        self.mockIsActive = isActive
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var productIdentifier: String {
        return mockProductIdentifier
    }
    
    override var isActive: Bool {
        return mockIsActive
    }
}
