import SwiftUI

// MARK: - Feature Gate View
struct FeatureGateView<Content: View>: View {
    let feature: SubscriptionFeature
    let content: Content
    let source: String
    let onUpgrade: (() -> Void)?
    
    @StateObject private var subscriptionManager = DependencyContainer.shared.resolve() as SubscriptionManager
    @State private var showPaywall = false
    
    init(
        feature: SubscriptionFeature,
        source: String = "feature_gate",
        onUpgrade: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.feature = feature
        self.source = source
        self.onUpgrade = onUpgrade
        self.content = content()
    }
    
    var body: some View {
        Group {
            if subscriptionManager.canAccessFeature(feature) {
                content
            } else {
                premiumFeatureOverlay
            }
        }
        .presentPaywall(
            isPresented: $showPaywall,
            configuration: subscriptionManager.getOptimalPaywallConfiguration(for: feature, source: source),
            source: source
        )
    }
    
    private var premiumFeatureOverlay: some View {
        VStack(spacing: 16) {
            // Lock Icon
            Image(systemName: "lock.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            // Feature Info
            VStack(spacing: 8) {
                Text(feature.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(feature.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Upgrade Button
            Button {
                if subscriptionManager.presentPaywallIfNeeded(for: feature, source: source) {
                    showPaywall = true
                    onUpgrade?()
                }
            } label: {
                HStack {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                    Text("Upgrade to Pro")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
        }
        .padding(24)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Inline Feature Gate
struct InlineFeatureGate: View {
    let feature: SubscriptionFeature
    let source: String
    let onUpgrade: (() -> Void)?
    
    @StateObject private var subscriptionManager = DependencyContainer.shared.resolve() as SubscriptionManager
    @State private var showPaywall = false
    
    init(
        feature: SubscriptionFeature,
        source: String = "inline_gate",
        onUpgrade: (() -> Void)? = nil
    ) {
        self.feature = feature
        self.source = source
        self.onUpgrade = onUpgrade
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Lock Icon
            Image(systemName: "lock.circle.fill")
                .foregroundColor(.gray)
                .font(.title3)
            
            // Feature Info
            VStack(alignment: .leading, spacing: 2) {
                Text(feature.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Requires Pro subscription")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Upgrade Button
            Button {
                if subscriptionManager.presentPaywallIfNeeded(for: feature, source: source) {
                    showPaywall = true
                    onUpgrade?()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "crown.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                    Text("Upgrade")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue)
                .cornerRadius(8)
            }
        }
        .padding(16)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
        .presentPaywall(
            isPresented: $showPaywall,
            configuration: subscriptionManager.getOptimalPaywallConfiguration(for: feature, source: source),
            source: source
        )
    }
}

// MARK: - Feature Toggle
struct FeatureToggle: View {
    let feature: SubscriptionFeature
    let isEnabled: Bool
    let onToggle: (Bool) -> Void
    let source: String
    
    @StateObject private var subscriptionManager = DependencyContainer.shared.resolve() as SubscriptionManager
    @State private var showPaywall = false
    
    init(
        feature: SubscriptionFeature,
        isEnabled: Bool,
        source: String = "feature_toggle",
        onToggle: @escaping (Bool) -> Void
    ) {
        self.feature = feature
        self.isEnabled = isEnabled
        self.source = source
        self.onToggle = onToggle
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(feature.name)
                        .font(.body)
                        .fontWeight(.medium)
                    
                    if feature.isPremiumOnly && !subscriptionManager.canAccessFeature(feature) {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                    }
                }
                
                Text(feature.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if subscriptionManager.canAccessFeature(feature) {
                Toggle("", isOn: Binding(
                    get: { isEnabled },
                    set: onToggle
                ))
            } else {
                Button {
                    if subscriptionManager.presentPaywallIfNeeded(for: feature, source: source) {
                        showPaywall = true
                    }
                } label: {
                    Text("Pro")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .cornerRadius(6)
                }
            }
        }
        .presentPaywall(
            isPresented: $showPaywall,
            configuration: subscriptionManager.getOptimalPaywallConfiguration(for: feature, source: source),
            source: source
        )
    }
}

// MARK: - Alarm Count Badge
struct AlarmCountBadge: View {
    @StateObject private var subscriptionManager = DependencyContainer.shared.resolve() as SubscriptionManager
    @State private var showPaywall = false
    
    var body: some View {
        if !subscriptionManager.currentSubscriptionStatus.isPremium {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    if let remaining = subscriptionManager.getRemainingAlarms() {
                        Text("\(remaining) alarms left")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Text("this month")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Button {
                    showPaywall = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "infinity")
                            .font(.caption2)
                        Text("Unlimited")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(10)
            .presentPaywall(
                isPresented: $showPaywall,
                configuration: subscriptionManager.getOptimalPaywallConfiguration(
                    for: .unlimitedAlarms,
                    source: "alarm_count_badge"
                ),
                source: "alarm_count_badge"
            )
        }
    }
}

// MARK: - Voice Selection Gate
struct VoiceSelectionGate: View {
    let selectedVoice: AlarmTone
    let onVoiceChange: (AlarmTone) -> Void
    
    @StateObject private var subscriptionManager = DependencyContainer.shared.resolve() as SubscriptionManager
    @State private var showPaywall = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Voice Personality")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(AlarmTone.allCases, id: \.self) { tone in
                    voiceOptionButton(tone)
                }
            }
        }
        .presentPaywall(
            isPresented: $showPaywall,
            configuration: subscriptionManager.getOptimalPaywallConfiguration(
                for: .allVoices,
                source: "voice_selection"
            ),
            source: "voice_selection"
        )
    }
    
    private func voiceOptionButton(_ tone: AlarmTone) -> some View {
        let isSelected = selectedVoice == tone
        let isLocked = tone != .energetic && !subscriptionManager.canAccessFeature(.allVoices)
        
        return Button {
            if isLocked {
                showPaywall = true
            } else {
                onVoiceChange(tone)
            }
        } label: {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: tone.iconName)
                        .font(.title2)
                        .foregroundColor(isSelected ? .white : (isLocked ? .gray : .primary))
                    
                    if isLocked {
                        Spacer()
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Text(tone.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : (isLocked ? .gray : .primary))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        isSelected ? Color.blue : (isLocked ? Color.gray.opacity(0.1) : Color.gray.opacity(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? Color.blue : (isLocked ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2)),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isLocked && !subscriptionManager.canAccessFeature(.allVoices))
    }
}

// MARK: - AlarmTone Extension for Display
extension AlarmTone {
    var iconName: String {
        switch self {
        case .gentle:
            return "leaf.fill"
        case .energetic:
            return "bolt.fill"
        case .toughLove:
            return "flame.fill"
        case .storyteller:
            return "book.fill"
        }
    }
    
    var displayName: String {
        switch self {
        case .gentle:
            return "Gentle"
        case .energetic:
            return "Energetic"
        case .toughLove:
            return "Tough Love"
        case .storyteller:
            return "Storyteller"
        }
    }
}

// MARK: - Preview
struct FeatureGateView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            FeatureGateView(feature: .unlimitedAlarms, source: "preview") {
                Text("Premium Content Here")
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
            
            InlineFeatureGate(feature: .allVoices, source: "preview")
            
            AlarmCountBadge()
        }
        .padding()
    }
}
