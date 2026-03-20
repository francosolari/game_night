import SwiftUI

struct GameImagePickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = GameImageUploadViewModel()

    let game: Game
    let onImageUploaded: (String) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.accentColor)

                    VStack(spacing: 4) {
                        Text("Upload Game Image")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Add a custom image for \(game.name)")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(Color(.systemGray6))
                .cornerRadius(12)

                PhotoPickerButton(
                    title: "Pick from Photos",
                    icon: "photo.on.rectangle",
                    action: { image in
                        if let imageData = image.jpegData(compressionQuality: 0.8) {
                            await viewModel.uploadGameImage(imageData, gameId: game.id)
                        }
                    },
                    onSuccess: {
                        if let url = viewModel.uploadedImageUrl {
                            onImageUploaded(url)
                            dismiss()
                        }
                    },
                    onError: { error in
                        print("Image upload failed: \(error)")
                    }
                )

                Spacer()
            }
            .padding()
            .navigationTitle("Game Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    GameImagePickerSheet(
        game: .preview,
        onImageUploaded: { _ in }
    )
}
