//
//  􀜖 AddParticipantSheetView.swift
//  Rio
//
//  Created by ChatGPT on 10/30/25.
//

import SwiftUI

struct AddParticipantSheetView: View {
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 54))
                    .foregroundStyle(.secondary)

                Text("TODO: Build add participant flow")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .navigationTitle("Add Participant")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onDismiss)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    AddParticipantSheetView {}
}
