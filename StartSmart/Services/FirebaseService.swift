//
//  FirebaseService.swift
//  StartSmart
//
//  Created by StartSmart Team on 9/11/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import FirebaseCore
import Combine

// MARK: - Firebase Configuration Protocol

/// Protocol defining Firebase service operations
protocol FirebaseServiceProtocol {
    // Authentication
    var isUserSignedIn: Bool { get }
    var currentUser: User? { get }
    
    func signInWithApple(idToken: String, nonce: String) async throws -> User
    func signInWithGoogle(idToken: String, accessToken: String) async throws -> User
    func signOut() throws
    
    // User Profile
    func saveUserProfile(_ userProfile: UserProfile) async throws
    func loadUserProfile(userId: String) async throws -> UserProfile?
    
    // Alarms
    func saveAlarm(_ alarm: Alarm, userId: String) async throws
    func loadUserAlarms(userId: String) async throws -> [Alarm]
    func deleteAlarm(alarmId: String, userId: String) async throws
    
    // Content Storage
    func uploadAudioContent(data: Data, fileName: String) async throws -> URL
    func downloadAudioContent(url: URL) async throws -> Data
}

// MARK: - Firebase Service Implementation

/// Firebase service managing authentication, Firestore, and Storage operations
@MainActor
class FirebaseService: FirebaseServiceProtocol, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isUserSignedIn: Bool = false
    @Published var currentUser: User?
    
    // MARK: - Private Properties
    
    private let auth = Auth.auth()
    private let firestore = Firestore.firestore()
    private let storage = Storage.storage()
    
    private var authStateListenerHandle: AuthStateDidChangeListenerHandle?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        setupAuthStateListener()
    }
    
    deinit {
        if let handle = authStateListenerHandle {
            auth.removeStateDidChangeListener(handle)
        }
    }
    
    // MARK: - Authentication State Management
    
    private func setupAuthStateListener() {
        authStateListenerHandle = auth.addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUser = user
                self?.isUserSignedIn = user != nil
            }
        }
    }
    
    // MARK: - Authentication Methods
    
    func signInWithApple(idToken: String, nonce: String) async throws -> User {
        let credential = OAuthProvider.credential(
            providerID: AuthProviderID.apple,
            idToken: idToken,
            rawNonce: nonce
        )
        
        let result = try await auth.signIn(with: credential)
        
        // Create user profile if new user
        if let user = result.user, result.additionalUserInfo?.isNewUser == true {
            let userProfile = UserProfile(
                id: user.uid,
                email: user.email ?? "",
                displayName: user.displayName ?? "User",
                createdAt: Date(),
                subscriptionTier: .free,
                preferences: UserPreferences()
            )
            try await saveUserProfile(userProfile)
        }
        
        return result.user
    }
    
    func signInWithGoogle(idToken: String, accessToken: String) async throws -> User {
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: accessToken
        )
        
        let result = try await auth.signIn(with: credential)
        
        // Create user profile if new user
        if let user = result.user, result.additionalUserInfo?.isNewUser == true {
            let userProfile = UserProfile(
                id: user.uid,
                email: user.email ?? "",
                displayName: user.displayName ?? "User",
                createdAt: Date(),
                subscriptionTier: .free,
                preferences: UserPreferences()
            )
            try await saveUserProfile(userProfile)
        }
        
        return result.user
    }
    
    func signOut() throws {
        try auth.signOut()
    }
    
    // MARK: - User Profile Management
    
    func saveUserProfile(_ userProfile: UserProfile) async throws {
        let userRef = firestore.collection("users").document(userProfile.id)
        let data = try userProfile.toDictionary()
        try await userRef.setData(data)
    }
    
    func loadUserProfile(userId: String) async throws -> UserProfile? {
        let userRef = firestore.collection("users").document(userId)
        let document = try await userRef.getDocument()
        
        guard document.exists, let data = document.data() else {
            return nil
        }
        
        return try UserProfile.fromDictionary(data)
    }
    
    // MARK: - Alarm Management
    
    func saveAlarm(_ alarm: Alarm, userId: String) async throws {
        let alarmRef = firestore
            .collection("users")
            .document(userId)
            .collection("alarms")
            .document(alarm.id.uuidString)
        
        let data = try alarm.toDictionary()
        try await alarmRef.setData(data)
    }
    
    func loadUserAlarms(userId: String) async throws -> [Alarm] {
        let alarmsRef = firestore
            .collection("users")
            .document(userId)
            .collection("alarms")
        
        let snapshot = try await alarmsRef.getDocuments()
        
        return try snapshot.documents.compactMap { document in
            try Alarm.fromDictionary(document.data())
        }
    }
    
    func deleteAlarm(alarmId: String, userId: String) async throws {
        let alarmRef = firestore
            .collection("users")
            .document(userId)
            .collection("alarms")
            .document(alarmId)
        
        try await alarmRef.delete()
    }
    
    // MARK: - Storage Management
    
    func uploadAudioContent(data: Data, fileName: String) async throws -> URL {
        let storageRef = storage.reference().child("audio/\(fileName)")
        
        let metadata = StorageMetadata()
        metadata.contentType = "audio/mpeg"
        
        _ = try await storageRef.putDataAsync(data, metadata: metadata)
        return try await storageRef.downloadURL()
    }
    
    func downloadAudioContent(url: URL) async throws -> Data {
        let storageRef = storage.reference(forURL: url.absoluteString)
        return try await storageRef.data(maxSize: 50 * 1024 * 1024) // 50MB max
    }
}

// MARK: - Firebase Configuration

/// Firebase configuration manager
class FirebaseConfiguration {
    
    /// Configure Firebase with GoogleService-Info.plist
    static func configure() {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let _ = NSDictionary(contentsOfFile: path) else {
            fatalError("GoogleService-Info.plist not found. Please add it to the Resources folder.")
        }
        
        FirebaseApp.configure()
    }
}

// MARK: - Data Model Extensions

extension UserProfile {
    func toDictionary() throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        let json = try JSONSerialization.jsonObject(with: data)
        return json as? [String: Any] ?? [:]
    }
    
    static func fromDictionary(_ dict: [String: Any]) throws -> UserProfile {
        let data = try JSONSerialization.data(withJSONObject: dict)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(UserProfile.self, from: data)
    }
}

extension Alarm {
    func toDictionary() throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        let json = try JSONSerialization.jsonObject(with: data)
        return json as? [String: Any] ?? [:]
    }
    
    static func fromDictionary(_ dict: [String: Any]) throws -> Alarm {
        let data = try JSONSerialization.data(withJSONObject: dict)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Alarm.self, from: data)
    }
}

// MARK: - Firebase Errors

enum FirebaseServiceError: LocalizedError {
    case userNotSignedIn
    case profileNotFound
    case uploadFailed(String)
    case downloadFailed(String)
    case configurationMissing
    
    var errorDescription: String? {
        switch self {
        case .userNotSignedIn:
            return "User must be signed in to perform this action"
        case .profileNotFound:
            return "User profile not found"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .downloadFailed(let message):
            return "Download failed: \(message)"
        case .configurationMissing:
            return "Firebase configuration is missing"
        }
    }
}
