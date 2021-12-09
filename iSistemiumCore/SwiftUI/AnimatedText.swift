//
// Created by Edgar Jan Vuicik on 2021-11-29.
// Copyright (c) 2021 Sistemium UAB. All rights reserved.
//

import SwiftUI

struct AnimatedText: View {
    @State var text = ""
    @State private var index = 0
    @State private var timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(text)
            .font(.system(size: 20))
                .frame(minWidth: 140, alignment: .leading)
                .onReceive(timer) { _ in
                    if index < 3 {
                        text += "."
                        index += 1
                    } else {
                        text = String(text.dropLast(3))
                        index = 0
                    }
                }
    }
}
