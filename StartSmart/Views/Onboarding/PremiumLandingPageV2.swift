import SwiftUI

// MARK: - Premium Landing Page V2 (New Design)
struct PremiumLandingPageV2: View {
    @State private var animationStarted = false
    @State private var scrollOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Background with gradients
            BackgroundView()
            
            VStack(spacing: 0) {
                // Status Bar
                StatusBarView()
                
                // Main Content
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .center, spacing: 0) {
                        // Logo Section
                        LogoSectionView()
                            .opacity(animationStarted ? 1 : 0)
                            .offset(y: animationStarted ? 0 : 20)
                        
                        // Headlines
                        HeadlineView()
                            .opacity(animationStarted ? 1 : 0)
                            .offset(y: animationStarted ? 0 : 20)
                            .padding(.top, 16)
                        
                        // Live Activity Feed
                        LiveActivityFeedView()
                            .opacity(animationStarted ? 1 : 0)
                            .offset(y: animationStarted ? 0 : 20)
                            .padding(.top, 40)
                            .padding(.horizontal, 32)
                        
                        // Social Proof
                        SocialProofView()
                            .opacity(animationStarted ? 1 : 0)
                            .offset(y: animationStarted ? 0 : 20)
                            .padding(.top, 40)
                            .padding(.horizontal, 32)
                        
                        // Trust Section
                        TrustSectionView()
                            .opacity(animationStarted ? 1 : 0)
                            .offset(y: animationStarted ? 0 : 20)
                            .padding(.top, 40)
                            .padding(.horizontal, 32)
                        
                        // Bottom Section
                        BottomSectionView()
                            .opacity(animationStarted ? 1 : 0)
                            .offset(y: animationStarted ? 0 : 20)
                            .padding(.top, 40)
                            .padding(.horizontal, 32)
                            .padding(.bottom, 40)
                    }
                    .padding(.top, 60)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.1)) {
                animationStarted = true
            }
        }
    }
}

// MARK: - Background View
struct BackgroundView: View {
    var body: some View {
        ZStack {
            // Base dark background
            Color(red: 0.05, green: 0.05, blue: 0.12)
                .ignoresSafeArea()
            
            // Radial gradient - top left (purple)
            RadialGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.54, green: 0.39, blue: 0.82).opacity(0.15),
                    Color.clear
                ]),
                center: .topLeading,
                startRadius: 0,
                endRadius: 200
            )
            .ignoresSafeArea()
            
            // Radial gradient - bottom right (indigo)
            RadialGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.39, green: 0.40, blue: 0.95).opacity(0.15),
                    Color.clear
                ]),
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 200
            )
            .ignoresSafeArea()
            
            // Linear gradient overlay
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.06, green: 0.06, blue: 0.12),
                    Color(red: 0.10, green: 0.10, blue: 0.18)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Status Bar
struct StatusBarView: View {
    var body: some View {
        HStack {
            Text("4:56")
                .font(.system(size: 15, weight: .semibold))
            
            Spacer()
            
            HStack(spacing: 6) {
                Text("●●●●")
                    .font(.system(size: 13))
                Text("📶")
                Text("100%")
                    .font(.system(size: 13))
            }
        }
        .foregroundColor(.white.opacity(0.9))
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
}

// MARK: - Logo Section
struct LogoSectionView: View {
    var body: some View {
        VStack(spacing: 24) {
            // Icon with gradient background
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 22)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.545, green: 0.408, blue: 0.961),
                                Color(red: 0.388, green: 0.408, blue: 0.945)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 88, height: 88)
                    .shadow(color: Color(red: 0.545, green: 0.408, blue: 0.961).opacity(0.4), radius: 24, y: 4)
                
                // Inner highlight
                RoundedRectangle(cornerRadius: 21)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.1),
                                Color.clear
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 88, height: 88)
                
                // Sunrise icon
                VStack(spacing: 0) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                        .shadow(color: Color.white.opacity(0.3), radius: 2, y: 2)
                    
                    Spacer()
                        .frame(height: 8)
                    
                    // Horizon line
                    Capsule()
                        .fill(Color.white.opacity(0.9))
                        .frame(height: 2)
                }
                .frame(width: 32, height: 32)
            }
            
            // Brand name
            Text("StartSmart")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

// MARK: - Headline View
struct HeadlineView: View {
    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            VStack(alignment: .center, spacing: 0) {
                Text("Stop hitting snooze.")
                Text("Start crushing goals.")
            }
            .font(.system(size: 32, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .lineSpacing(1.2)
            .multilineTextAlignment(.center)
            
            Text("AI-powered wake-up messages\npersonalized for your daily goals")
                .font(.system(size: 17, weight: .medium, design: .default))
                .foregroundColor(.white.opacity(0.7))
                .lineSpacing(1.5)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
    }
}

// MARK: - Live Activity Feed
struct LiveActivityFeedView: View {
    @State private var activities = [
        ActivityItem(name: "Marcus", goal: "woke up for his 6AM workout", location: "New York", streak: "Day 12"),
        ActivityItem(name: "Sarah", goal: "crushed her presentation prep", location: "London", streak: "Day 28"),
        ActivityItem(name: "James", goal: "started his study session", location: "Tokyo", streak: "Day 7"),
        ActivityItem(name: "Mike", goal: "woke up for his 6AM workout", location: "New York", streak: "Day 12"),
        ActivityItem(name: "Ashley", goal: "crushed her presentation prep", location: "London", streak: "Day 28"),
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("RIGHT NOW")
                    .font(.system(size: 13, weight: .semibold, design: .default))
                    .foregroundColor(.white.opacity(0.6))
                    .tracking(0.5)
                
                Spacer()
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(red: 0.065, green: 0.722, blue: 0.506))
                        .frame(width: 6, height: 6)
                    
                    Text("Live")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(red: 0.065, green: 0.722, blue: 0.506))
                }
            }
            .padding(.bottom, 4)
            
            // Activity items
            VStack(spacing: 12) {
                ForEach(activities, id: \.self) { activity in
                    ActivityCard(activity: activity)
                }
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.04))
        .backdrop()
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Activity Card
struct ActivityCard: View {
    let activity: ActivityItem
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Avatar
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.545, green: 0.408, blue: 0.961),
                            Color(red: 0.388, green: 0.408, blue: 0.945)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 36, height: 36)
                .overlay(
                    Text(String(activity.name.prefix(1)))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                )
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text("\(activity.name) \(activity.goal)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text("Just now • \(activity.location)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            }
            
            Spacer()
            
            // Badge
            Text(activity.streak)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(red: 0.655, green: 0.486, blue: 0.980))
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color(red: 0.545, green: 0.408, blue: 0.961).opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(red: 0.545, green: 0.408, blue: 0.961).opacity(0.3), lineWidth: 1)
                )
                .cornerRadius(6)
        }
        .padding(12)
        .background(Color.white.opacity(0.03))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

// MARK: - Activity Item Model
struct ActivityItem: Hashable {
    let name: String
    let goal: String
    let location: String
    let streak: String
}

// MARK: - Social Proof
struct SocialProofView: View {
    var body: some View {
        HStack(spacing: 16) {
            // Rating badge
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(red: 1.0, green: 0.722, blue: 0.0))
                
                Text("4.8")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(Color.white.opacity(0.04))
            .backdrop()
            .cornerRadius(100)
            .overlay(
                RoundedRectangle(cornerRadius: 100)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            
            Divider()
                .frame(height: 16)
                .foregroundColor(.white.opacity(0.1))
            
            Text("50,000+ users")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
            
            Spacer()
        }
    }
}

// MARK: - Trust Section
struct TrustSectionView: View {
    var body: some View {
        HStack(spacing: 12) {
            TrustItem(
                icon: "shield.fill",
                label: "Private &\nsecure"
            )
            
            TrustItem(
                icon: "xmark",
                label: "No ads\never"
            )
            
            TrustItem(
                icon: "wifi.slash",
                label: "Works\noffline"
            )
        }
    }
}

// MARK: - Trust Item
struct TrustItem: View {
    let icon: String
    let label: String
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 0.545, green: 0.408, blue: 0.961).opacity(0.1))
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(red: 0.545, green: 0.408, blue: 0.961))
            }
            .frame(width: 32, height: 32)
            
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .lineSpacing(1.3)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.02))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

// MARK: - Bottom Section
struct BottomSectionView: View {
    var body: some View {
        VStack(spacing: 16) {
            // Trial Banner
            VStack(spacing: 2) {
                Text("7-day free trial")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("No credit card required")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(Color(red: 0.545, green: 0.408, blue: 0.961).opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(red: 0.545, green: 0.408, blue: 0.961).opacity(0.2), lineWidth: 1)
            )
            .cornerRadius(12)
            
            // CTA Button
            Button(action: {}) {
                Text("Get Started")
                    .font(.system(size: 17, weight: .semibold, design: .default))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(17)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.545, green: 0.408, blue: 0.961),
                                Color(red: 0.388, green: 0.408, blue: 0.945)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(14)
                    .shadow(color: Color(red: 0.545, green: 0.408, blue: 0.961).opacity(0.4), radius: 24, y: 8)
            }
            
            // Sign In Link
            HStack(spacing: 0) {
                Text("Already have an account? ")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                
                Text("Sign in")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(red: 0.545, green: 0.408, blue: 0.961))
            }
            .frame(maxWidth: .infinity)
            
            // Legal
            VStack(spacing: 4) {
                Text("By continuing, you agree to our")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.3))
                
                HStack(spacing: 4) {
                    Link("Terms of Service", destination: URL(string: "https://www.startsmartmobile.com/support") ?? URL(fileURLWithPath: ""))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                    
                    Text("and")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.3))
                    
                    Link("Privacy Policy", destination: URL(string: "https://www.startsmartmobile.com/support") ?? URL(fileURLWithPath: ""))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Backdrop Modifier (Glassmorphism)
struct BackdropModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
    }
}

extension View {
    func backdrop() -> some View {
        modifier(BackdropModifier())
    }
}

#Preview {
    PremiumLandingPageV2()
}
