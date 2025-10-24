//
//  UpgradePromptView.swift
//  StartSmart
//
//  Reusable upgrade prompt for freemium conversion
//

import SwiftUI

/// Reusable upgrade prompt shown when free users hit limits
struct UpgradePromptView: View {
    let title: String
    let message: String
    let featureIcon: String
    let onUpgrade: () -> Void
    let onDismiss: (() -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    
    init(
        title: String,
        message: String,
        featureIcon: String = "star.fill",
        onUpgrade: @escaping () -> Void,
        onDismiss: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.featureIcon = featureIcon
        self.onUpgrade = onUpgrade
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: featureIcon)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(.white)
            }
            
            // Title
            Text(title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
            
            // Message
            Text(message)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            
            // Benefits list
            VStack(spacing: 12) {
                BenefitRow(icon: "infinity", text: "Unlimited AI alarms")
                BenefitRow(icon: "waveform", text: "Access all voice styles")
                BenefitRow(icon: "chart.line.uptrend.xyaxis", text: "Advanced analytics")
                BenefitRow(icon: "crown.fill", text: "Priority support")
            }
            .padding(.vertical, 8)
            
            // CTA Button
            Button(action: {
                onUpgrade()
            }) {
                HStack {
                    Image(systemName: "crown.fill")
                        .font(.title3)
                    
                    Text("Upgrade to Premium")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            
            // Dismiss button (if provided)
            if let onDismiss = onDismiss {
                Button(action: {
                    onDismiss()
                }) {
                    Text("Maybe Later")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(32)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
    }
}

// MARK: - Benefit Row

struct BenefitRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

// MARK: - Preview

#if DEBUG
struct UpgradePromptView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            UpgradePromptView(
                title: "You've Reached Your Limit",
                message: "You've used all 15 free alarms this month. Upgrade to Premium for unlimited AI-powered wake-ups.",
                featureIcon: "alarm.fill",
                onUpgrade: { print("Upgrade tapped") },
                onDismiss: { print("Dismiss tapped") }
            )
            .padding(20)
        }
    }
}
#endif

