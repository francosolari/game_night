import SwiftUI

struct EventCoverPickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = EventCoverUploadViewModel()

    let event: GameEvent
    let onImageUploaded: (String) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.accentColor)

                    VStack(spacing: 4) {
                        Text("Event Cover Image")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Add a custom cover for \(event.title)")
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
                        if let imageData = image.jpegData(compressionQuality: 0.85) {
                            await viewModel.uploadEventCover(imageData, eventId: event.id)
                        }
                    },
                    onSuccess: {
                        if let url = viewModel.uploadedImageUrl {
                            onImageUploaded(url)
                            dismiss()
                        }
                    },
                    onError: { error in
                        print("Cover upload failed: \(error)")
                    }
                )

                Spacer()
            }
            .padding()
            .navigationTitle("Event Cover")
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
    EventCoverPickerSheet(
        event: .preview,
        onImageUploaded: { _ in }
    )
}
