//
//  VoiceOrbView.swift
//  RoleEase
//
//  Created by Lakshman Ryali on 03/08/26.
//

import SwiftUI

struct VoiceOrbView: View {
    var isActive: Bool

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let blobCount = 4

                for i in 0..<blobCount {
                    let angle = time * 0.6 + Double(i) * (.pi * 2 / Double(blobCount))
                    let spread = size.width * 0.16 * (isActive ? 1.0 : 0.35)
                    let offsetX = cos(angle) * spread
                    let offsetY = sin(angle * 1.3) * spread * 0.6
                    let blobSize = size.width * 0.42

                    let rect = CGRect(
                        x: center.x + offsetX - blobSize / 2,
                        y: center.y + offsetY - blobSize / 2,
                        width: blobSize,
                        height: blobSize
                    )

                    let hueA = (0.72 + Double(i) * 0.03 + sin(time * 0.25) * 0.03).truncatingRemainder(dividingBy: 1)
                    let hueB = (0.80 + Double(i) * 0.02).truncatingRemainder(dividingBy: 1)

                    context.fill(
                        Path(ellipseIn: rect),
                        with: .linearGradient(
                            Gradient(colors: [
                                Color(hue: hueA, saturation: 0.75, brightness: 0.95),
                                Color(hue: hueB, saturation: 0.7, brightness: 0.75)
                            ]),
                            startPoint: CGPoint(x: rect.minX, y: rect.minY),
                            endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
                        )
                    )
                }
            }
            .blur(radius: 28)
        }
        .frame(height: 160)
        .animation(.easeInOut(duration: 0.4), value: isActive)
    }
}
