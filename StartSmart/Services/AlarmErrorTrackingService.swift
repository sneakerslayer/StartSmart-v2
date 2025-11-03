import Foundation
import FirebaseFirestore
import os.log

/// Tracks alarm-related errors and analytics events
@MainActor
class AlarmErrorTrackingService {
    static let shared = AlarmErrorTrackingService()
    
    private let logger = Logger(subsystem: "com.startsmart.mobile", category: "AlarmErrorTracking")
    private let firestore = Firestore.firestore()
    
    private init() {
        logger.info("📊 AlarmErrorTrackingService initialized")
    }
    
    /// Track an alarm playback error
    func trackPlaybackError(
        alarmId: String,
        error: Error,
        errorType: PlaybackErrorType,
        context: [String: Any] = [:]
    ) async {
        logger.error("❌ Playback error tracked: \(errorType.rawValue) - \(error.localizedDescription)")
        
        let errorData: [String: Any] = [
            "alarmID": alarmId,
            "errorType": errorType.rawValue,
            "errorMessage": error.localizedDescription,
            "errorDescription": String(describing: error),
            "timestamp": Date(),
            "context": context
        ]
        
        // Log to Firestore if user is authenticated
        await logToFirestore(eventName: "alarm_playback_error", data: errorData)
        
        // Also log to console for debugging
        logger.error("📊 Error details: \(errorData)")
    }
    
    /// Track alarm dismissal success
    func trackDismissalSuccess(
        alarmId: String,
        method: String,
        audioPlayed: Bool,
        context: [String: Any] = [:]
    ) async {
        logger.info("✅ Dismissal success tracked: \(method)")
        
        let successData: [String: Any] = [
            "alarmID": alarmId,
            "method": method,
            "audioPlayed": audioPlayed,
            "timestamp": Date(),
            "context": context
        ]
        
        await logToFirestore(eventName: "alarm_dismissal_success", data: successData)
    }
    
    /// Track app launch detection
    func trackAppLaunchDetection(
        source: String,
        alarmId: String?,
        success: Bool,
        context: [String: Any] = [:]
    ) async {
        logger.info("🚀 App launch detection tracked: \(source) - \(success ? "success" : "failed")")
        
        var launchData: [String: Any] = [
            "source": source,
            "success": success,
            "timestamp": Date(),
            "context": context
        ]
        
        if let alarmId = alarmId {
            launchData["alarmID"] = alarmId
        }
        
        await logToFirestore(eventName: "app_launch_detection", data: launchData)
    }
    
    /// Track audio file resolution
    func trackAudioFileResolution(
        alarmId: String,
        found: Bool,
        path: String?,
        fallbackUsed: Bool,
        context: [String: Any] = [:]
    ) async {
        logger.info("🔍 Audio file resolution tracked: found=\(found), fallback=\(fallbackUsed)")
        
        var resolutionData: [String: Any] = [
            "alarmID": alarmId,
            "found": found,
            "fallbackUsed": fallbackUsed,
            "timestamp": Date(),
            "context": context
        ]
        
        if let path = path {
            resolutionData["filePath"] = path
        }
        
        await logToFirestore(eventName: "audio_file_resolution", data: resolutionData)
    }
    
    /// Track WakeUpIntent execution
    func trackWakeUpIntent(
        alarmId: String,
        methods: [String],
        success: Bool,
        errors: [String] = [],
        context: [String: Any] = [:]
    ) async {
        logger.info("🎯 WakeUpIntent tracked: success=\(success), methods=\(methods.joined(separator: ", "))")
        
        let intentData: [String: Any] = [
            "alarmID": alarmId,
            "methods": methods,
            "success": success,
            "errors": errors,
            "timestamp": Date(),
            "context": context
        ]
        
        await logToFirestore(eventName: "wakeup_intent_execution", data: intentData)
    }
    
    /// Private helper to log to Firestore
    private func logToFirestore(eventName: String, data: [String: Any]) async {
        do {
            // Get Firebase service from dependency container (use resolveSafe to wait for initialization)
            guard let firebaseService: FirebaseServiceProtocol = await DependencyContainer.shared.resolveSafe() else {
                logger.info("ℹ️ FirebaseService not available yet - skipping Firestore logging")
                return
            }
            
            // Get current user ID
            guard let userId = firebaseService.currentUser?.id.uuidString else {
                logger.info("ℹ️ No authenticated user - skipping Firestore logging")
                return
            }
            
            // Create event document
            let eventRef = firestore
                .collection("users")
                .document(userId)
                .collection("alarm_events")
                .document()
            
            var eventData = data
            eventData["eventName"] = eventName
            
            try await eventRef.setData(eventData)
            logger.info("✅ Event logged to Firestore: \(eventName)")
            
        } catch {
            logger.error("❌ Failed to log event to Firestore: \(error.localizedDescription)")
            // Don't throw - analytics failures shouldn't break app functionality
        }
    }
}

/// Types of playback errors
enum PlaybackErrorType: String {
    case fileNotFound = "file_not_found"
    case fileLoadError = "file_load_error"
    case playbackFailed = "playback_failed"
    case audioSessionError = "audio_session_error"
    case permissionDenied = "permission_denied"
    case timeout = "timeout"
    case unknown = "unknown"
}

