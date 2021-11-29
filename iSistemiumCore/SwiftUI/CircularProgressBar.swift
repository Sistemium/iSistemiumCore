//
// Created by Edgar Jan Vuicik on 2021-11-29.
// Copyright (c) 2021 Sistemium UAB. All rights reserved.
//

import SwiftUI

struct CircularProgressBar: View {
    @Binding var value: Float

    var body: some View {
        ZStack {
            Circle()
                    .stroke(lineWidth: 10.0)
                    .opacity(0.3)
                    .foregroundColor(Color.blue)

            Circle()
                    .trim(from: 0.0, to: CGFloat(min(value, 1.0)))
                    .stroke(style: StrokeStyle(lineWidth: 10.0, lineCap: .round, lineJoin: .round))
                    .opacity(0.6)
                    .foregroundColor(Color.blue)
                    .rotationEffect(Angle(degrees: 270.0))
                    .animation(.linear)

            Text(String(format: "%.0f %%", min(value, 1.0) * 100.0))
                    .font(.largeTitle)
        }
    }
}