//
// Created by Edgar Jan Vuicik on 2021-11-29.
// Copyright (c) 2021 Sistemium UAB. All rights reserved.
//

import SwiftUI

struct AnimatedText: View {
    @State var text = ""
    @State private var index = 0
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(text)
                .frame(minWidth: 120, alignment: .leading)
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
