
//
//  PaperBackgroundOverlay.swift
//  HoAh
//
//  Created by HoAh Assistant on 2024.
//

import SwiftUI

struct PaperBackgroundOverlay: View {
    var body: some View {
        ZStack {
            // Top-left darkened aging spot
            RadialGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.8, green: 0.7, blue: 0.5).opacity(0.08),
                    Color.clear
                ]),
                center: .topLeading,
                startRadius: 50,
                endRadius: 600
            )
            
            // Bottom-right darkened aging spot
            RadialGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.85, green: 0.75, blue: 0.55).opacity(0.1),
                    Color.clear
                ]),
                center: .bottomTrailing,
                startRadius: 50,
                endRadius: 700
            )
            
            // Subtle "grain" using a repeated pattern of very faint noise-like gradients
            // (Simulated with a tiled geometry or just a few minimal spots for now to keep perf high)
            GeometryReader { geometry in
                Path { path in
                    // Draw random tiny flecks
                    let w = geometry.size.width
                    let h = geometry.size.height
                    // Seeded random for consistency
                    var seed = 42
                    let count = Int(w * h / 5000) // Density
                    
                    for _ in 0..<min(count, 500) { // Limit max specks
                        seed = (seed * 1664525 + 1013904223) % 4294967296
                        let x = Double(seed % Int(w))
                        seed = (seed * 1664525 + 1013904223) % 4294967296
                        let y = Double(seed % Int(h))
                        path.addEllipse(in: CGRect(x: x, y: y, width: 1.5, height: 1.5))
                    }
                }
                .fill(Color(red: 0.4, green: 0.3, blue: 0.2).opacity(0.15)) // Coffee specs
            }
        }
    }
}
