//
//  LottieView.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 05/09/26.
//


//
//  Bridges Airbnb's Lottie (UIKit) into SwiftUI. Used for the Jobs
//  loading + empty states. Loops by default; honors Reduce Motion by
//  showing a static first frame instead of animating.
//


import SwiftUI
import Lottie

struct LottieView: UIViewRepresentable {
    let name: String
    var loopMode: LottieLoopMode = .loop
    var speed: CGFloat = 1.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear

        let animation = LottieAnimationView(name: name)
        animation.contentMode = .scaleAspectFit
        animation.backgroundBehavior = .forceFinish
        animation.animationSpeed = speed
        animation.loopMode = loopMode
        animation.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(animation)

        // Pin the animation to fill the container; the container's size is
        // driven by SwiftUI's .frame(), so the animation follows it.
        NSLayoutConstraint.activate([
            animation.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            animation.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            animation.topAnchor.constraint(equalTo: container.topAnchor),
            animation.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        // Let SwiftUI's frame win: don't impose an intrinsic size, and don't
        // resist being sized down.
        animation.setContentHuggingPriority(.defaultLow, for: .horizontal)
        animation.setContentHuggingPriority(.defaultLow, for: .vertical)
        animation.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        animation.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        if reduceMotion {
            animation.currentProgress = 0
        } else {
            animation.play()
        }

        context.coordinator.animation = animation
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let animation = context.coordinator.animation else { return }
        if reduceMotion {
            animation.pause()
            animation.currentProgress = 0
        } else {
            // Always ensure it's playing when visible — covers view rebuilds
            // (tab switches, backgrounding) where the initial play() didn't stick.
            if !animation.isAnimationPlaying {
                animation.play()
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var animation: LottieAnimationView?
    }
}
