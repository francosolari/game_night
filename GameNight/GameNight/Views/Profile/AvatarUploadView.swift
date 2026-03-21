import SwiftUI
import PhotosUI

struct AvatarUploadView: View {
    let currentAvatarUrl: String?
    let userId: UUID?
    let onAvatarUpdated: (String) -> Void
    let onAvatarDeleted: () -> Void

    @StateObject private var avatarUploadViewModel = AvatarUploadViewModel()
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var showCropSheet = false
    @State private var errorToast: ToastItem?
    @State private var isDeleting = false

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            ZStack(alignment: .bottomTrailing) {
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .images,
                    label: {
                        AvatarView(url: currentAvatarUrl, size: 80)
                    }
                )

                if avatarUploadViewModel.isUploading || isDeleting {
                    ProgressView()
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Theme.Colors.cardBackground)
                                .shadow(radius: 2)
                        )
                } else {
                    ZStack {
                        Circle()
                            .fill(Theme.Colors.primaryAction)
                            .shadow(radius: 2)
                        Image(systemName: "camera.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                    }
                    .frame(width: 32, height: 32)
                }
            }
            .disabled(avatarUploadViewModel.isUploading || isDeleting)

            VStack(spacing: Theme.Spacing.sm) {
                Text("Tap to change profile picture")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textTertiary)

                if currentAvatarUrl != nil {
                    Button {
                        Task { await deleteAvatar() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 12))
                            Text("Remove picture")
                        }
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.error)
                    }
                    .disabled(isDeleting || avatarUploadViewModel.isUploading)
                }
            }
        }
        .onChange(of: selectedItem) { newItem in
            Task {
                if let data = try await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                    showCropSheet = true
                }
            }
        }
        .sheet(isPresented: $showCropSheet) {
            if let image = selectedImage {
                CircularCropView(image: image, isPresented: $showCropSheet) { croppedImage in
                    Task { await uploadAvatar(croppedImage) }
                }
            }
        }
        .onChange(of: avatarUploadViewModel.uploadedImageUrl) {
            if let url = avatarUploadViewModel.uploadedImageUrl {
                onAvatarUpdated(url)
                selectedImage = nil
            }
        }
        .toast($errorToast)
    }

    private func uploadAvatar(_ image: UIImage) async {
        guard let userId = userId else { return }

        guard let compressedData = image.jpegData(compressionQuality: 0.85) else {
            errorToast = ToastItem(style: .error, message: "Failed to compress image")
            return
        }

        await avatarUploadViewModel.uploadAvatar(compressedData, userId: userId)

        if let error = avatarUploadViewModel.error {
            errorToast = ToastItem(style: .error, message: error.localizedDescription)
        }
    }

    private func deleteAvatar() async {
        guard let userId = userId else { return }
        isDeleting = true

        do {
            let path = "avatars/\(userId.uuidString)/avatar.jpg"
            try await R2StorageService.shared.deleteImage(path: path)

            var user = try await SupabaseService.shared.fetchCurrentUser()
            user.avatarUrl = nil
            try await SupabaseService.shared.updateUser(user)

            onAvatarDeleted()
        } catch {
            errorToast = ToastItem(style: .error, message: "Failed to delete picture")
        }

        isDeleting = false
    }
}

// MARK: - Circular Crop View
struct CircularCropView: View {
    let image: UIImage
    @Binding var isPresented: Bool
    let onCrop: (UIImage) -> Void

    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    let circleSize: CGFloat = 280

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.xl) {
                Text("Position & Scale")
                    .font(Theme.Typography.headlineMedium)
                    .foregroundColor(Theme.Colors.textPrimary)

                ZStack {
                    // Image with pinch-to-zoom
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            SimultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        scale = value
                                    },
                                DragGesture()
                                    .onChanged { value in
                                        offset = value.translation
                                    }
                            )
                        )

                    // Circular crop guide
                    Circle()
                        .stroke(Theme.Colors.primaryAction, lineWidth: 2)
                        .frame(width: circleSize, height: circleSize)
                }
                .frame(height: 400)
                .background(Theme.Colors.backgroundElevated)
                .clipShape(Circle())
                .frame(width: circleSize, height: circleSize)

                Spacer()

                Button("Use Photo") {
                    cropAndDismiss()
                }
                .buttonStyle(PrimaryButtonStyle(isEnabled: true))
            }
            .padding(Theme.Spacing.xl)
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { isPresented = false }
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
        }
    }

    private func cropAndDismiss() {
        let cropSize = circleSize
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: cropSize, height: cropSize))

        let croppedImage = renderer.image { context in
            let drawRect = CGRect(x: 0, y: 0, width: cropSize, height: cropSize)

            // Draw clipped circle
            context.cgContext.setFillColor(UIColor.black.cgColor)
            context.cgContext.fillEllipse(in: drawRect)
            context.cgContext.setBlendMode(.sourceIn)

            // Draw scaled and offset image
            let scaledSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let drawOrigin = CGPoint(
                x: (cropSize - scaledSize.width) / 2 + offset.width,
                y: (cropSize - scaledSize.height) / 2 + offset.height
            )

            image.draw(in: CGRect(origin: drawOrigin, size: scaledSize))
        }

        onCrop(croppedImage)
        isPresented = false
    }
}

#Preview {
    AvatarUploadView(
        currentAvatarUrl: nil,
        userId: UUID(),
        onAvatarUpdated: { _ in },
        onAvatarDeleted: { }
    )
    .padding()
}
