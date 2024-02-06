//
//  ButtonComponent.swift
//  Rise and Shine
//
//  Created by loren on 2/6/24.
//

import Foundation
import SwiftUI

struct CustomButton: View {
    var title: String
    var action: () -> Void
    var foregroundColor: Color = .black // Default color, customizable
    var backgroundColor: Color = .accentColor // Default color, customizable

    var body: some View {
        Button(action: action) {
            HStack {
                Spacer()
                Text(title)
                Spacer()
            }

                .foregroundColor(foregroundColor)
                .padding(.all)
                .background(backgroundColor)
                .cornerRadius(10)
        }
        .padding(.all)
        .shadow(radius: /*@START_MENU_TOKEN@*/10/*@END_MENU_TOKEN@*/)
    }
}
