//
//  MultiModelResponseView.swift
//  AIgent
//
//  Created by Joel Dehlin on 1/31/26.
//

import SwiftUI

struct MultiModelResponseView: View {
    let responses: [ProviderResponse]
    @Environment(\.dismiss) private var dismiss

    @State private var selectedResponse: ProviderResponse?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(responses) { response in
                            ProviderTab(
                                response: response,
                                isSelected: selectedResponse?.id == response.id
                            )
                            .onTapGesture {
                                selectedResponse = response
                            }
                        }
                    }
                    .padding()
                }
                .background(Color(uiColor: .systemGroupedBackground))

                Divider()

                // Response content
                if let selected = selectedResponse {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            // Provider and model header
                            HStack {
                                Image(systemName: selected.provider.iconName)
                                Text(selected.provider.rawValue)
                                Text("·")
                                    .foregroundColor(.secondary)
                                Text(selected.model)
                                    .foregroundColor(.secondary)

                                Spacer()

                                Text(selected.timestamp, style: .relative)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(uiColor: .systemGray6))

                            // Response text
                            Text(selected.content)
                                .textSelection(.enabled)
                                .padding()
                        }
                    }
                }
            }
            .navigationTitle("\(responses.count) Model Responses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if selectedResponse == nil {
                    selectedResponse = responses.first
                }
            }
        }
    }
}

// MARK: - Provider Tab

struct ProviderTab: View {
    let response: ProviderResponse
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: response.provider.iconName)
                .font(.title3)

            Text(response.provider.rawValue)
                .font(.caption)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(isSelected ? Color.blue : Color(uiColor: .systemGray5))
        .foregroundColor(isSelected ? .white : .primary)
        .cornerRadius(12)
    }
}
