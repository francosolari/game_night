import SwiftUI
import PhotosUI
import UIKit

struct PhotoPickerButton: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isLoading = false
    @State private var errorMessage: String?

    let title: String
    let icon: String
    let action: (UIImage) async throws -> Void
    var onSuccess: (() -> Void)?
    var onError: ((Error) -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            PhotosPicker(
                selection: $selectedItem,
                matching: .images,
                label: {
                    HStack(spacing: 8) {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                        Text(title)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.accentColor)
                    .cornerRadius(8)
                }
            )
            .disabled(isLoading)

            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8, anchor: .center)
                    Text("Uploading...")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(height: 44)
            }

            if let errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                    Text(errorMessage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.red)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.red.opacity(0.1))
                .cornerRadius(6)
            }

            if let selectedImage {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Preview")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .cornerRadius(8)
                        .clipped()
                }
            }
        }
        .onChange(of: selectedItem) { newValue in
            Task {
                await handleImageSelection(newValue)
            }
        }
    }

    private func handleImageSelection(_ item: PhotosPickerItem?) async {
        guard let item else { return }

        do {
            isLoading = true
            errorMessage = nil

            guard let data = try await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data) else {
                throw NSError(domain: "PhotoPicker", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load image"])
            }

            selectedImage = uiImage
            try await action(uiImage)
            onSuccess?()
            selectedItem = nil
        } catch {
            errorMessage = error.localizedDescription
            selectedImage = nil
            onError?(error)
        }
        isLoading = false
    }
}

#Preview {
    VStack {
        PhotoPickerButton(
            title: "Choose Image",
            icon: "photo",
            action: { _ in }
        )
        .padding()
        Spacer()
    }
}
