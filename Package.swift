// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "StartSmart",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "StartSmart",
            targets: ["StartSmart"]
        ),
    ],
    dependencies: [
        // Firebase SDK for authentication, storage, and backend services
        .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "10.15.0"),
        
        // ElevenLabs SDK for text-to-speech (if available, otherwise we'll use HTTP client)
        // Note: We'll implement HTTP client for now as official SDK may not exist
        
        // HTTP client for API requests
        .package(url: "https://github.com/Alamofire/Alamofire", from: "5.8.0"),
        
        // SwiftUI Navigation
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.2.0"),
        
        // Keychain for secure storage
        .package(url: "https://github.com/evgenyneu/keychain-swift", from: "20.0.0"),
        
        // Audio processing for TTS and playback
        .package(url: "https://github.com/AudioKit/AudioKit", from: "5.6.0"),
    ],
    targets: [
        .target(
            name: "StartSmart",
            dependencies: [
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseStorage", package: "firebase-ios-sdk"),
                .product(name: "FirebaseAnalytics", package: "firebase-ios-sdk"),
                .product(name: "Alamofire", package: "Alamofire"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "KeychainSwift", package: "keychain-swift"),
                .product(name: "AudioKit", package: "AudioKit"),
            ]
        ),
        .testTarget(
            name: "StartSmartTests",
            dependencies: ["StartSmart"]
        ),
    ]
)
