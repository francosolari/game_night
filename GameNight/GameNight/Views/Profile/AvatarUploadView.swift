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
    @State private var displayUrl: String?

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            ZStack(alignment: .bottomTrailing) {
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .images,
                    label: {
                        AvatarView(url: displayUrl, size: 80)
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
                displayUrl = url
                onAvatarUpdated(url)
                selectedImage = nil
            }
        }
        .onAppear {
            displayUrl = currentAvatarUrl
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

            displayUrl = nil
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
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    let circleSize: CGFloat = 280

    /// The display size of the image when it fills the circle (scaledToFill behavior).
    private var baseFillSize: CGSize {
        guard image.size.width > 0, image.size.height > 0 else {
            return CGSize(width: circleSize, height: circleSize)
        }
        let imageAspect = image.size.width / image.size.height
        if imageAspect > 1.0 {
            // Landscape — height matches circle, width overflows
            return CGSize(width: circleSize * imageAspect, height: circleSize)
        } else {
            // Portrait — width matches circle, height overflows
            return CGSize(width: circleSize, height: circleSize / imageAspect)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.xl) {
                Text("Position & Scale")
                    .font(Theme.Typography.headlineMedium)
                    .foregroundColor(Theme.Colors.textPrimary)

                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: circleSize, height: circleSize)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            SimultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        scale = lastScale * value
                                    }
                                    .onEnded { _ in
                                        scale = max(scale, 1.0)
                                        lastScale = scale
                                    },
                                DragGesture()
                                    .onChanged { value in
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                    }
                            )
                        )

                    // Circular crop guide
                    Circle()
                        .stroke(Theme.Colors.primaryAction, lineWidth: 2)
                        .frame(width: circleSize, height: circleSize)
                }
                .frame(width: circleSize, height: circleSize)
                .clipShape(Circle())

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
        // Render at 2x for retina quality
        let outputSize = circleSize * 2
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: outputSize, height: outputSize))

        let croppedImage = renderer.image { _ in
            // Calculate scaled display size matching what's on screen
            let displaySize = CGSize(
                width: baseFillSize.width * scale,
                height: baseFillSize.height * scale
            )

            // Map to output coordinates (2x of screen points)
            let scaleFactor: CGFloat = outputSize / circleSize
            let drawSize = CGSize(
                width: displaySize.width * scaleFactor,
                height: displaySize.height * scaleFactor
            )
            let drawOrigin = CGPoint(
                x: (outputSize - drawSize.width) / 2 + offset.width * scaleFactor,
                y: (outputSize - drawSize.height) / 2 + offset.height * scaleFactor
            )

            image.draw(in: CGRect(origin: drawOrigin, size: drawSize))
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
