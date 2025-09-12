import Foundation
import SwiftUI
import UIKit
import os.log

/// Asset optimization utilities for reducing bundle size and improving performance
final class AssetOptimizer {
    static let shared = AssetOptimizer()
    
    private let logger = Logger(subsystem: "com.startsmart.assets", category: "optimization")
    private let imageCache = NSCache<NSString, UIImage>()
    
    private init() {
        configureImageCache()
    }
    
    private func configureImageCache() {
        imageCache.countLimit = 100 // Maximum 100 cached images
        imageCache.totalCostLimit = 50 * 1024 * 1024 // 50MB cache limit
    }
    
    // MARK: - Image Optimization
    
    /// Optimize image for display with automatic resizing and compression
    func optimizeImage(
        _ image: UIImage,
        maxWidth: CGFloat = 1024,
        maxHeight: CGFloat = 1024,
        compressionQuality: CGFloat = 0.8
    ) -> UIImage? {
        // Check if optimization is needed
        if image.size.width <= maxWidth && image.size.height <= maxHeight {
            return image
        }
        
        // Calculate new size maintaining aspect ratio
        let aspectRatio = image.size.width / image.size.height
        var newSize: CGSize
        
        if aspectRatio > 1 {
            // Landscape
            newSize = CGSize(width: min(maxWidth, image.size.width), 
                           height: min(maxWidth / aspectRatio, image.size.height))
        } else {
            // Portrait or square
            newSize = CGSize(width: min(maxHeight * aspectRatio, image.size.width),
                           height: min(maxHeight, image.size.height))
        }
        
        // Resize image
        return resizeImage(image, to: newSize, compressionQuality: compressionQuality)
    }
    
    private func resizeImage(_ image: UIImage, to size: CGSize, compressionQuality: CGFloat) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: size))
        
        guard let resizedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            return nil
        }
        
        // Compress if needed
        if compressionQuality < 1.0 {
            guard let imageData = resizedImage.jpegData(compressionQuality: compressionQuality),
                  let compressedImage = UIImage(data: imageData) else {
                return resizedImage
            }
            return compressedImage
        }
        
        return resizedImage
    }
    
    // MARK: - Cached Image Loading
    
    /// Load and cache image with automatic optimization
    func loadOptimizedImage(
        named name: String,
        bundle: Bundle = .main,
        maxSize: CGSize = CGSize(width: 1024, height: 1024),
        compressionQuality: CGFloat = 0.8
    ) -> UIImage? {
        let cacheKey = "\(name)_\(maxSize.width)x\(maxSize.height)_\(compressionQuality)" as NSString
        
        // Check cache first
        if let cachedImage = imageCache.object(forKey: cacheKey) {
            return cachedImage
        }
        
        // Load original image
        guard let originalImage = UIImage(named: name, in: bundle, compatibleWith: nil) else {
            logger.error("Failed to load image: \(name)")
            return nil
        }
        
        // Optimize image
        let optimizedImage = optimizeImage(
            originalImage,
            maxWidth: maxSize.width,
            maxHeight: maxSize.height,
            compressionQuality: compressionQuality
        ) ?? originalImage
        
        // Cache optimized image
        let cost = Int(optimizedImage.size.width * optimizedImage.size.height * 4) // Estimate memory cost
        imageCache.setObject(optimizedImage, forKey: cacheKey, cost: cost)
        
        logger.info("Loaded and cached optimized image: \(name)")
        return optimizedImage
    }
    
    // MARK: - Bundle Analysis
    
    /// Analyze bundle size and provide optimization recommendations
    func analyzeBundleSize() -> BundleAnalysis {
        let bundlePath = Bundle.main.bundlePath
        let bundleSize = directorySize(atPath: bundlePath)
        
        var analysis = BundleAnalysis(totalSize: bundleSize)
        
        // Analyze different asset types
        analysis.imageAssets = analyzeImageAssets()
        analysis.audioAssets = analyzeAudioAssets()
        analysis.codeSize = analyzeCodeSize()
        analysis.recommendations = generateOptimizationRecommendations(for: analysis)
        
        return analysis
    }
    
    private func analyzeImageAssets() -> AssetAnalysis {
        guard let resourcePath = Bundle.main.resourcePath else {
            return AssetAnalysis(type: "Images", totalSize: 0, fileCount: 0, averageSize: 0)
        }
        
        let imageExtensions = ["png", "jpg", "jpeg", "gif", "heic", "webp"]
        var totalSize: Int64 = 0
        var fileCount = 0
        
        for ext in imageExtensions {
            let files = findFiles(withExtension: ext, in: resourcePath)
            fileCount += files.count
            totalSize += files.reduce(0) { $0 + fileSize(atPath: $1) }
        }
        
        return AssetAnalysis(
            type: "Images",
            totalSize: totalSize,
            fileCount: fileCount,
            averageSize: fileCount > 0 ? totalSize / Int64(fileCount) : 0
        )
    }
    
    private func analyzeAudioAssets() -> AssetAnalysis {
        guard let resourcePath = Bundle.main.resourcePath else {
            return AssetAnalysis(type: "Audio", totalSize: 0, fileCount: 0, averageSize: 0)
        }
        
        let audioExtensions = ["mp3", "wav", "m4a", "aiff", "caf"]
        var totalSize: Int64 = 0
        var fileCount = 0
        
        for ext in audioExtensions {
            let files = findFiles(withExtension: ext, in: resourcePath)
            fileCount += files.count
            totalSize += files.reduce(0) { $0 + fileSize(atPath: $1) }
        }
        
        return AssetAnalysis(
            type: "Audio",
            totalSize: totalSize,
            fileCount: fileCount,
            averageSize: fileCount > 0 ? totalSize / Int64(fileCount) : 0
        )
    }
    
    private func analyzeCodeSize() -> AssetAnalysis {
        guard let executablePath = Bundle.main.executablePath else {
            return AssetAnalysis(type: "Code", totalSize: 0, fileCount: 1, averageSize: 0)
        }
        
        let codeSize = fileSize(atPath: executablePath)
        
        return AssetAnalysis(
            type: "Code",
            totalSize: codeSize,
            fileCount: 1,
            averageSize: codeSize
        )
    }
    
    private func generateOptimizationRecommendations(for analysis: BundleAnalysis) -> [OptimizationRecommendation] {
        var recommendations: [OptimizationRecommendation] = []
        
        // Image optimization recommendations
        if analysis.imageAssets.averageSize > 500 * 1024 { // 500KB average
            recommendations.append(
                OptimizationRecommendation(
                    type: .imageCompression,
                    title: "Optimize Large Images",
                    description: "Average image size is \(formatBytes(analysis.imageAssets.averageSize)). Consider compressing images or using WebP format.",
                    estimatedSavings: analysis.imageAssets.totalSize / 3, // Estimate 33% savings
                    priority: .high
                )
            )
        }
        
        // Bundle size recommendations
        if analysis.totalSize > 100 * 1024 * 1024 { // 100MB
            recommendations.append(
                OptimizationRecommendation(
                    type: .bundleSize,
                    title: "Large Bundle Size",
                    description: "Total bundle size is \(formatBytes(analysis.totalSize)). Consider app thinning and on-demand resources.",
                    estimatedSavings: analysis.totalSize / 5, // Estimate 20% savings
                    priority: .medium
                )
            )
        }
        
        // Audio optimization recommendations
        if analysis.audioAssets.totalSize > 10 * 1024 * 1024 { // 10MB
            recommendations.append(
                OptimizationRecommendation(
                    type: .audioCompression,
                    title: "Optimize Audio Files",
                    description: "Audio assets total \(formatBytes(analysis.audioAssets.totalSize)). Consider using compressed formats like AAC.",
                    estimatedSavings: analysis.audioAssets.totalSize / 2, // Estimate 50% savings
                    priority: .medium
                )
            )
        }
        
        return recommendations
    }
    
    // MARK: - Utility Methods
    
    private func directorySize(atPath path: String) -> Int64 {
        let fileManager = FileManager.default
        var totalSize: Int64 = 0
        
        if let enumerator = fileManager.enumerator(atPath: path) {
            for case let fileName as String in enumerator {
                let filePath = (path as NSString).appendingPathComponent(fileName)
                totalSize += fileSize(atPath: filePath)
            }
        }
        
        return totalSize
    }
    
    private func fileSize(atPath path: String) -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
    
    private func findFiles(withExtension ext: String, in directory: String) -> [String] {
        let fileManager = FileManager.default
        var files: [String] = []
        
        if let enumerator = fileManager.enumerator(atPath: directory) {
            for case let fileName as String in enumerator {
                if fileName.lowercased().hasSuffix(".\(ext.lowercased())") {
                    files.append((directory as NSString).appendingPathComponent(fileName))
                }
            }
        }
        
        return files
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    // MARK: - Memory Management
    
    func clearImageCache() {
        imageCache.removeAllObjects()
        logger.info("Image cache cleared")
    }
    
    func getImageCacheStats() -> CacheStats {
        return CacheStats(
            objectCount: imageCache.countLimit,
            totalCost: imageCache.totalCostLimit,
            currentCount: 0, // NSCache doesn't provide current count
            currentCost: 0   // NSCache doesn't provide current cost
        )
    }
}

// MARK: - Data Models

struct BundleAnalysis {
    let totalSize: Int64
    var imageAssets: AssetAnalysis = AssetAnalysis(type: "Images", totalSize: 0, fileCount: 0, averageSize: 0)
    var audioAssets: AssetAnalysis = AssetAnalysis(type: "Audio", totalSize: 0, fileCount: 0, averageSize: 0)
    var codeSize: AssetAnalysis = AssetAnalysis(type: "Code", totalSize: 0, fileCount: 0, averageSize: 0)
    var recommendations: [OptimizationRecommendation] = []
    
    var formattedTotalSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSize)
    }
}

struct AssetAnalysis {
    let type: String
    let totalSize: Int64
    let fileCount: Int
    let averageSize: Int64
    
    var formattedTotalSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSize)
    }
    
    var formattedAverageSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: averageSize)
    }
}

struct OptimizationRecommendation {
    let type: OptimizationType
    let title: String
    let description: String
    let estimatedSavings: Int64
    let priority: Priority
    
    var formattedSavings: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: estimatedSavings)
    }
    
    enum OptimizationType {
        case imageCompression
        case audioCompression
        case bundleSize
        case codeOptimization
    }
    
    enum Priority {
        case low, medium, high
        
        var color: Color {
            switch self {
            case .low: return .green
            case .medium: return .orange
            case .high: return .red
            }
        }
    }
}

struct CacheStats {
    let objectCount: Int
    let totalCost: Int
    let currentCount: Int
    let currentCost: Int
}

// MARK: - SwiftUI Integration

struct OptimizedAsyncImage: View {
    let url: URL?
    let placeholder: Image
    let maxSize: CGSize
    let compressionQuality: CGFloat
    
    init(
        url: URL?,
        placeholder: Image = Image(systemName: "photo"),
        maxSize: CGSize = CGSize(width: 300, height: 300),
        compressionQuality: CGFloat = 0.8
    ) {
        self.url = url
        self.placeholder = placeholder
        self.maxSize = maxSize
        self.compressionQuality = compressionQuality
    }
    
    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                placeholder
                    .foregroundColor(.gray.opacity(0.3))
                    .frame(maxWidth: maxSize.width, maxHeight: maxSize.height)
                    .aspectRatio(contentMode: .fit)
                
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: maxSize.width, maxHeight: maxSize.height)
                
            case .failure(_):
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.red.opacity(0.6))
                    .frame(maxWidth: maxSize.width, maxHeight: maxSize.height)
                
            @unknown default:
                placeholder
                    .frame(maxWidth: maxSize.width, maxHeight: maxSize.height)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: url)
    }
}

// MARK: - Bundle Analysis View

#if DEBUG
struct BundleAnalysisView: View {
    @State private var analysis: BundleAnalysis?
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Analyzing bundle...")
                } else if let analysis = analysis {
                    AnalysisResultView(analysis: analysis)
                } else {
                    Button("Analyze Bundle") {
                        performAnalysis()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Bundle Analysis")
            .onAppear {
                if analysis == nil {
                    performAnalysis()
                }
            }
        }
    }
    
    private func performAnalysis() {
        isLoading = true
        
        Task {
            let result = await Task.detached(priority: .background) {
                AssetOptimizer.shared.analyzeBundleSize()
            }.value
            
            await MainActor.run {
                analysis = result
                isLoading = false
            }
        }
    }
}

struct AnalysisResultView: View {
    let analysis: BundleAnalysis
    
    var body: some View {
        List {
            Section("Bundle Size") {
                HStack {
                    Text("Total Size")
                    Spacer()
                    Text(analysis.formattedTotalSize)
                        .fontWeight(.semibold)
                }
            }
            
            Section("Asset Breakdown") {
                AssetRow(analysis: analysis.imageAssets)
                AssetRow(analysis: analysis.audioAssets)
                AssetRow(analysis: analysis.codeSize)
            }
            
            if !analysis.recommendations.isEmpty {
                Section("Optimization Recommendations") {
                    ForEach(analysis.recommendations.indices, id: \.self) { index in
                        RecommendationRow(recommendation: analysis.recommendations[index])
                    }
                }
            }
        }
    }
}

struct AssetRow: View {
    let analysis: AssetAnalysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(analysis.type)
                    .fontWeight(.medium)
                Spacer()
                Text(analysis.formattedTotalSize)
                    .fontWeight(.semibold)
            }
            
            HStack {
                Text("\(analysis.fileCount) files")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Avg: \(analysis.formattedAverageSize)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct RecommendationRow: View {
    let recommendation: OptimizationRecommendation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(recommendation.priority.color)
                    .frame(width: 8, height: 8)
                
                Text(recommendation.title)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("Save \(recommendation.formattedSavings)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(4)
            }
            
            Text(recommendation.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
#endif
