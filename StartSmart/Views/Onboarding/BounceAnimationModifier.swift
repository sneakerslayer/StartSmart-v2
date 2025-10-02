import SwiftUI

struct BounceAnimationModifier: ViewModifier {
    let animate: Bool
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(animate ? 1.0 : 0.95)
            .animation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0.2), value: animate)
    }
}

extension View {
    func bounceAnimation(_ animate: Bool) -> some View {
        modifier(BounceAnimationModifier(animate: animate))
    }
}


