//
//  SpeedometerGaugeStyle.swift
//  scoria
//
//  Created by John Matthew Weston on 12/12/25.
//

import SwiftUI

struct SpeedometerGaugeStyle: GaugeStyle {
    private var purpleGradient = LinearGradient(gradient: Gradient(colors: [ .black,.gray,.white ]),
                                                startPoint: .trailing, endPoint: .leading)

    func makeBody(configuration: Configuration) -> some View {
        ZStack {

            Circle()
                .foregroundColor(Color(.systemGray6))

            Circle()
                .trim(from: 0, to: 0.75 * configuration.value)
                .stroke(purpleGradient, lineWidth: 5)
                .rotationEffect(.degrees(135))

            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(Color.black, style: StrokeStyle(lineWidth: 10, lineCap: .butt, lineJoin: .round, dash: [1, 34], dashPhase: 0.0))
                .rotationEffect(.degrees(135))

            VStack {
                configuration.currentValueLabel
                    .font(.system(size: 12, weight: .thin, design: .rounded))
                    .foregroundColor(.gray)
                Text("Frame Rate [fps]")
                    .font(.system(.caption2, design: .rounded))
                    .bold()
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }

        }
        .frame(width: 68, height: 68)
    }
}

struct CustomGaugeView: View {

    @State private var currentSpeed = 140.0

    var body: some View {
        Gauge(value: currentSpeed, in: 0...200) {
            Image(systemName: "gauge.medium")
                .font(.system(size: 50.0))
        } currentValueLabel: {
            Text("\(currentSpeed.formatted(.number))")

        }
        .gaugeStyle(SpeedometerGaugeStyle())

    }
}
