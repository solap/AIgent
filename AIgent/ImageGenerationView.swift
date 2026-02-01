//
//  ImageGenerationView.swift
//  AIgent
//
//  Created by Joel Dehlin on 1/31/26.
//

import SwiftUI
import Photos

struct ImageGenerationView: View {
    @State private var prompt = ""
    @State private var selectedProvider: ImageGenProvider = .openAI
    @State private var isGenerating = false
    @State private var generatedImages: [ImageGenResponse] = []
    @State private var selectedImage: ImageGenResponse?
    @State private var showingSaveAlert = false
    @State private var saveAlertMessage = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Model Selector
                modelSelector
                Divider()

                // Generated Images Grid
                ScrollView {
                    if generatedImages.isEmpty && !isGenerating {
                        emptyState
                    } else {
                        imageGrid
                    }
                }

                Divider()

                // Input Area
                inputArea
            }
            .navigationTitle("Image Generation")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedImage) { response in
                FullImageView(response: response, onSave: { saveImage(response) })
            }
            .alert("Save Image", isPresented: $showingSaveAlert) {
                Button("OK") { }
            } message: {
                Text(saveAlertMessage)
            }
        }
    }

    // MARK: - Model Selector

    private var modelSelector: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(ImageGenProvider.allCases) { provider in
                    Button {
                        selectedProvider = provider
                    } label: {
                        if selectedProvider == provider {
                            Label("\(provider.rawValue) - \(provider.modelName)", systemImage: "checkmark")
                        } else {
                            Label("\(provider.rawValue) - \(provider.modelName)", systemImage: provider.iconName)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: selectedProvider.iconName)
                        .font(.caption)
                    Text(selectedProvider.modelName)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .font(.caption)
                .foregroundColor(.primary)
            }

            Spacer()

            // Generate All button
            Button {
                generateFromAll()
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: "sparkles.rectangle.stack")
                    Text("Generate All")
                }
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.purple.opacity(0.1))
                .foregroundColor(.purple)
                .cornerRadius(6)
            }
            .disabled(prompt.isEmpty || isGenerating)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "photo.artframe")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No images generated yet")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Enter a prompt below to generate images")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding()
    }

    // MARK: - Image Grid

    private var imageGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            ForEach(generatedImages) { response in
                ImageThumbnail(response: response)
                    .onTapGesture {
                        if response.imageData != nil {
                            selectedImage = response
                        }
                    }
            }

            if isGenerating {
                GeneratingPlaceholder()
            }
        }
        .padding()
    }

    // MARK: - Input Area

    private var inputArea: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Describe the image you want...", text: $prompt, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...5)
                .focused($isInputFocused)

            Button {
                generateImage()
            } label: {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 28))
                    .foregroundStyle(canGenerate ? .purple : .gray)
            }
            .disabled(!canGenerate || isGenerating)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(uiColor: .systemBackground))
    }

    private var canGenerate: Bool {
        !prompt.isEmpty
    }

    // MARK: - Actions

    private func generateImage() {
        guard !prompt.isEmpty else { return }

        let currentPrompt = prompt
        isInputFocused = false
        isGenerating = true

        Task {
            do {
                let imageData = try await ImageGenerationService.shared.generateImage(
                    prompt: currentPrompt,
                    provider: selectedProvider
                )
                let response = ImageGenResponse(provider: selectedProvider, imageData: imageData)
                await MainActor.run {
                    generatedImages.insert(response, at: 0)
                    isGenerating = false
                }
            } catch {
                let response = ImageGenResponse(provider: selectedProvider, error: error.localizedDescription)
                await MainActor.run {
                    generatedImages.insert(response, at: 0)
                    isGenerating = false
                }
            }
        }
    }

    private func generateFromAll() {
        guard !prompt.isEmpty else { return }

        let currentPrompt = prompt
        isInputFocused = false
        isGenerating = true

        Task {
            let responses = await ImageGenerationService.shared.generateImageFromAll(prompt: currentPrompt)
            await MainActor.run {
                generatedImages.insert(contentsOf: responses, at: 0)
                isGenerating = false
            }
        }
    }

    private func saveImage(_ response: ImageGenResponse) {
        guard let imageData = response.imageData,
              let image = UIImage(data: imageData) else {
            saveAlertMessage = "Failed to save image"
            showingSaveAlert = true
            return
        }

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            if status == .authorized || status == .limited {
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                DispatchQueue.main.async {
                    saveAlertMessage = "Image saved to Photos"
                    showingSaveAlert = true
                }
            } else {
                DispatchQueue.main.async {
                    saveAlertMessage = "Please allow photo access in Settings"
                    showingSaveAlert = true
                }
            }
        }
    }
}

// MARK: - Image Thumbnail

struct ImageThumbnail: View {
    let response: ImageGenResponse

    var body: some View {
        VStack(spacing: 4) {
            if let imageData = response.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 150)
                    .clipped()
                    .cornerRadius(12)
            } else if let error = response.error {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title)
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
                .frame(height: 150)
                .frame(maxWidth: .infinity)
                .background(Color(uiColor: .systemGray6))
                .cornerRadius(12)
            }

            HStack(spacing: 4) {
                Image(systemName: response.provider.iconName)
                Text(response.provider.modelName)
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        }
    }
}

// MARK: - Generating Placeholder

struct GeneratingPlaceholder: View {
    var body: some View {
        VStack(spacing: 8) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Generating...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(height: 150)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Full Image View

struct FullImageView: View {
    let response: ImageGenResponse
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                if let imageData = response.imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .padding()
                }
            }
            .navigationTitle("\(response.provider.rawValue) - \(response.provider.modelName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        onSave()
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                }
            }
        }
    }
}

#Preview {
    ImageGenerationView()
}
