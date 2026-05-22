//
//  DialWidgets.swift
//  CinderCone
//
//  Saab 900-style analog needle dial ported from indigo.
//  Design tokens scoped to this module so they can be shared across views.
//

import SwiftUI

// MARK: - Design Tokens

let coneAmber      = Color(red: 0.94, green: 0.56, blue: 0.16)
let coneLabelFont  = Font.system(size: 9.5, weight: .semibold)
let coneLabelColor = Color.white.opacity(0.42)

// MARK: - Analog Knob (Saab-style needle gauge)

/// Vertical-drag needle dial.  270° sweep, 11 tick marks, amber needle.
struct AnalogKnob: View {
    let label: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let format: String
    var size: CGFloat = 72

    @State private var dragStartValue: Float = 0
    @State private var isDragging = false

    private static let minAngle:   Double = 210.0
    private static let sweepAngle: Double = 270.0
    private static let tickCount:  Int    = 11

    private var normalized: Double {
        let n = Double((value - range.lowerBound) / (range.upperBound - range.lowerBound))
        return max(0, min(1, n))
    }
    private var needleAngle: Double { Self.minAngle + normalized * Self.sweepAngle }
    private var valueFontSize: CGFloat { size * 0.20 }

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(Color(white: 1, opacity: isDragging ? 0.14 : 0.07))
                    .shadow(color: .black.opacity(0.55), radius: 6, x: 0, y: 3)

                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: size * 0.018)
                    .padding(size * 0.025)

                let tickR = size * 0.42
                ForEach(0..<Self.tickCount, id: \.self) { i in
                    let frac    = Double(i) / Double(Self.tickCount - 1)
                    let angle   = Self.minAngle + frac * Self.sweepAngle
                    let isMajor = i % 5 == 0
                    Rectangle()
                        .fill(isMajor ? Color.white.opacity(0.65) : Color.white.opacity(0.30))
                        .frame(width: isMajor ? size * 0.030 : size * 0.018,
                               height: isMajor ? size * 0.13  : size * 0.08)
                        .offset(y: -tickR)
                        .rotationEffect(.degrees(angle))
                }

                let r        = size / 2
                let tipDist  = r * 0.64
                let tailDist = r * 0.15
                let needleH  = tipDist + tailDist
                let needleW  = size * 0.033

                ZStack {
                    RoundedRectangle(cornerRadius: needleW / 2)
                        .fill(coneAmber.opacity(isDragging ? 1.0 : 0.92))
                        .frame(width: needleW, height: needleH)
                        .offset(y: -((tipDist - tailDist) / 2))

                    Circle()
                        .fill(Color(white: 0.25))
                        .overlay(Circle().stroke(coneAmber.opacity(0.45), lineWidth: 0.5))
                        .frame(width: size * 0.11, height: size * 0.11)
                }
                .rotationEffect(.degrees(needleAngle))
                .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.65),
                           value: needleAngle)

                Text(String(format: format, value))
                    .font(.system(size: valueFontSize, weight: .medium, design: .monospaced))
                    .foregroundColor(coneAmber.opacity(0.92))
                    .offset(y: size * 0.19)
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { drag in
                        if !isDragging {
                            isDragging = true
                            dragStartValue = value
                        }
                        let span  = range.upperBound - range.lowerBound
                        let delta = Float(-drag.translation.height) * span / 140
                        value = min(range.upperBound, max(range.lowerBound, dragStartValue + delta))
                    }
                    .onEnded { _ in isDragging = false }
            )

            Text(label)
                .font(coneLabelFont)
                .foregroundColor(coneLabelColor)
                .kerning(1.2)
                .textCase(.uppercase)
                .fixedSize()
        }
    }
}

// MARK: - Push Button (Ferrari steering-wheel latch style)

/// Round illuminated push button. Gradient inverts on latch to simulate physical press-in.
/// Dials behind it dim rather than disappear — keeps panel layout stable.
struct PushButton: View {
    let label: String
    let systemImage: String
    @Binding var isOn: Bool
    var activeColor: Color = coneAmber
    var size: CGFloat = 40

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                // Outer bezel — fixed dark ring
                Circle()
                    .fill(Color(white: 0.10))
                    .shadow(color: .black.opacity(0.65), radius: 4, x: 0, y: 2)

                // Button cap — gradient flips direction to simulate convex→sunken
                Circle()
                    .fill(
                        LinearGradient(
                            colors: isOn
                                ? [activeColor.opacity(0.22), activeColor.opacity(0.08)]
                                : [Color(white: 0.34), Color(white: 0.17)],
                            startPoint: isOn ? .bottomTrailing : .topLeading,
                            endPoint:   isOn ? .topLeading     : .bottomTrailing
                        )
                    )
                    .padding(5)

                // Active rim glow
                if isOn {
                    Circle()
                        .strokeBorder(activeColor.opacity(0.72), lineWidth: 1.5)
                        .padding(5)
                }

                Image(systemName: systemImage)
                    .font(.system(size: size * 0.30, weight: .semibold))
                    .foregroundColor(isOn ? activeColor : Color.white.opacity(0.32))
            }
            .frame(width: size, height: size)
            .scaleEffect(isOn ? 0.92 : 1.0)
            .animation(.spring(response: 0.18, dampingFraction: 0.55), value: isOn)
            .onTapGesture { isOn.toggle() }

            Text(label)
                .font(coneLabelFont)
                .foregroundColor(coneLabelColor)
                .kerning(1.2)
                .textCase(.uppercase)
                .lineLimit(1)
        }
    }
}

// MARK: - Manettino Selector (Ferrari-style rotary mode dial)

/// Rotary selector — options fan 240° around a bezel ring.
/// Tap the central knob to cycle; tap a label to jump directly.
struct ManettinoSelector<T: Hashable>: View {
    let label: String
    let options: [(label: String, value: T)]
    @Binding var selection: T

    var ringR:  CGFloat = 26
    var labelR: CGFloat = 40
    var knobR:  CGFloat = 15

    private func optionAngle(for index: Int) -> Double {
        let count = options.count
        guard count > 1 else { return 0 }
        return -120.0 + Double(index) * 240.0 / Double(count - 1)
    }

    private var selectedIndex: Int {
        options.firstIndex(where: { $0.value == selection }) ?? 0
    }

    var body: some View {
        VStack(spacing: -4) {
            ZStack {
                Circle()
                    .fill(Color(white: 0.10))
                    .frame(width: ringR * 2, height: ringR * 2)

                Circle()
                    .stroke(Color.white.opacity(0.22), lineWidth: 1.5)
                    .frame(width: ringR * 2, height: ringR * 2)

                ForEach(0..<options.count, id: \.self) { i in
                    let isSelected = options[i].value == selection
                    Rectangle()
                        .fill(isSelected ? coneAmber : Color.white.opacity(0.22))
                        .frame(width: 1.5, height: 5)
                        .offset(y: -(ringR - 2.5))
                        .rotationEffect(.degrees(optionAngle(for: i)))
                }

                ForEach(0..<options.count, id: \.self) { i in
                    let angle = optionAngle(for: i)
                    let rad   = angle * .pi / 180
                    let isSelected = options[i].value == selection
                    Text(options[i].label)
                        .font(coneLabelFont)
                        .foregroundColor(isSelected ? coneAmber : Color.white.opacity(0.32))
                        .offset(x:  labelR * CGFloat(sin(rad)),
                                y: -labelR * CGFloat(cos(rad)))
                        .onTapGesture { selection = options[i].value }
                }

                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(colors: [Color(white: 0.35), Color(white: 0.16)],
                                           center: .topLeading,
                                           startRadius: 2, endRadius: knobR)
                        )
                        .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 0.5))
                        .shadow(color: .black.opacity(0.55), radius: 3, x: 0, y: 1)

                    RoundedRectangle(cornerRadius: 1)
                        .fill(coneAmber.opacity(0.92))
                        .frame(width: 2, height: knobR * 0.72)
                        .offset(y: -(knobR * 0.34))
                }
                .frame(width: knobR * 2, height: knobR * 2)
                .rotationEffect(.degrees(optionAngle(for: selectedIndex)))
                .animation(.spring(response: 0.32, dampingFraction: 0.65), value: selectedIndex)
                .onTapGesture {
                    selection = options[(selectedIndex + 1) % options.count].value
                }
            }
            .frame(width: labelR * 2 + 18, height: labelR * 2 + 4)

            Text(label)
                .font(coneLabelFont)
                .foregroundColor(coneLabelColor)
                .kerning(1.2)
                .textCase(.uppercase)
        }
    }
}
