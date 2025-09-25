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
            if let startSmartFeature = feature.startSmartFeature,
               subscriptionManager.canAccessFeature(startSmartFeature) {
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
                if let startSmartFeature = feature.startSmartFeature,
                   subscriptionManager.presentPaywallIfNeeded(for: startSmartFeature, source: source) {
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
                if let startSmartFeature = feature.startSmartFeature,
                   subscriptionManager.presentPaywallIfNeeded(for: startSmartFeature, source: source) {
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
                    
                    if feature.isPremiumOnly && !subscriptionManager.canAccessFeature(feature.startSmartFeature ?? .unlimitedAlarms) {
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
            
            if subscriptionManager.canAccessFeature(feature.startSmartFeature ?? .unlimitedAlarms) {
                Toggle("", isOn: Binding(
                    get: { isEnabled },
                    set: onToggle
                ))
            } else {
                Button {
                    if let startSmartFeature = feature.startSmartFeature,
                       subscriptionManager.presentPaywallIfNeeded(for: startSmartFeature, source: source) {
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
        let hasAllVoicesAccess = subscriptionManager.canAccessFeature(.allVoices)
        let isLocked = tone != .energetic && !hasAllVoicesAccess
        
        return Button(action: {
            if isLocked {
                showPaywall = true
            } else {
                onVoiceChange(tone)
            }
        }, label: {
            voiceButtonContent(tone: tone, isSelected: isSelected, isLocked: isLocked)
        })
        .buttonStyle(PlainButtonStyle())
        .disabled(isLocked && !hasAllVoicesAccess)
    }
    
    @ViewBuilder
    private func voiceButtonContent(tone: AlarmTone, isSelected: Bool, isLocked: Bool) -> some View {
        VStack(spacing: 8) {
            voiceButtonHeader(tone: tone, isSelected: isSelected, isLocked: isLocked)
            voiceButtonText(tone: tone, isSelected: isSelected, isLocked: isLocked)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 60)
        .padding(.horizontal, 8)
        .background(voiceButtonBackground(isSelected: isSelected, isLocked: isLocked))
    }
    
    @ViewBuilder
    private func voiceButtonHeader(tone: AlarmTone, isSelected: Bool, isLocked: Bool) -> some View {
        HStack {
            Image(systemName: tone.iconName)
                .font(.title2)
                .foregroundColor(voiceButtonIconColor(isSelected: isSelected, isLocked: isLocked))
            
            if isLocked {
                Spacer()
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
    
    @ViewBuilder
    private func voiceButtonText(tone: AlarmTone, isSelected: Bool, isLocked: Bool) -> some View {
        Text(tone.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(voiceButtonTextColor(isSelected: isSelected, isLocked: isLocked))
            .multilineTextAlignment(.center)
    }
    
    private func voiceButtonIconColor(isSelected: Bool, isLocked: Bool) -> Color {
        if isSelected { return .white }
        if isLocked { return .gray }
        return .primary
    }
    
    private func voiceButtonTextColor(isSelected: Bool, isLocked: Bool) -> Color {
        if isSelected { return .white }
        if isLocked { return .gray }
        return .primary
    }
    
    @ViewBuilder
    private func voiceButtonBackground(isSelected: Bool, isLocked: Bool) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(voiceButtonFillColor(isSelected: isSelected, isLocked: isLocked))
            .overlay(voiceButtonStroke(isSelected: isSelected, isLocked: isLocked))
    }
    
    private func voiceButtonFillColor(isSelected: Bool, isLocked: Bool) -> Color {
        if isSelected { return Color.blue }
        if isLocked { return Color.gray.opacity(0.1) }
        return Color.gray.opacity(0.05)
    }
    
    @ViewBuilder
    private func voiceButtonStroke(isSelected: Bool, isLocked: Bool) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(
                voiceButtonStrokeColor(isSelected: isSelected, isLocked: isLocked),
                lineWidth: isSelected ? 2 : 1
            )
    }
    
    private func voiceButtonStrokeColor(isSelected: Bool, isLocked: Bool) -> Color {
        if isSelected { return Color.blue }
        if isLocked { return Color.gray.opacity(0.3) }
        return Color.gray.opacity(0.2)
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
