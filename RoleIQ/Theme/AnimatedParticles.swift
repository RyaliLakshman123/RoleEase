//
//  AnimatedParticles.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 18/09/26.
//


import SwiftUI

struct AnimatedParticles: View {

    private struct Particle {
        let size: CGFloat
        let x: CGFloat
        let delay: Double
        let duration: Double
        let opacity: Double
    }

    private let particles: [Particle] = (0..<30).map { _ in
        Particle(
            size: CGFloat.random(in: 2...4),
            x: CGFloat.random(in: 0...1),
            delay: Double.random(in: 0...15),
            duration: Double.random(in: 8...16),
            opacity: Double.random(in: 0.2...0.6)
        )
    }

    var body: some View {

        TimelineView(
            .animation(minimumInterval: 1.0 / 30.0)
        ) { timeline in

            Canvas { context, size in

                let currentTime =
                    timeline.date.timeIntervalSinceReferenceDate

                for particle in particles {

                    let elapsed = currentTime + particle.delay

                    let progress =
                        (elapsed.truncatingRemainder(
                            dividingBy: particle.duration
                        )) / particle.duration

                    let x = particle.x * size.width

                    let y = size.height + 20
                        - (size.height + 40) * progress

                    let rect = CGRect(
                        x: x - particle.size / 2,
                        y: y - particle.size / 2,
                        width: particle.size,
                        height: particle.size
                    )

                    context.opacity = particle.opacity

                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(AppTheme.accentSoft)
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}
