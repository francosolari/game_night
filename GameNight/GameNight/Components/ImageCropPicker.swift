import SwiftUI
import UIKit

/// UIImagePickerController wrapper with allowsEditing=true for native crop+resize.
/// Returns a UIImage on selection.
struct ImageCropPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onImagePicked: (UIImage) -> Void
    var sourceType: UIImagePickerController.SourceType = .photoLibrary

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.allowsEditing = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImageCropPicker

        init(_ parent: ImageCropPicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            // Prefer the edited (cropped) image; fall back to original
            let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage
            parent.isPresented = false
            if let image {
                // Enforce square with letterboxing, then resize to max 1200px
                let squareImage = image.croppedToSquare()
                parent.onImagePicked(squareImage.resizedForUpload())
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
    }
}

extension UIImage {
    /// Crop to square aspect ratio with letterboxing for wide images.
    /// Maintains content without cutting off by adding transparent bars on top/bottom for wide images.
    func croppedToSquare() -> UIImage {
        let size = self.size
        let minDimension = min(size.width, size.height)

        // If already square (or close), return as-is
        if abs(size.width - size.height) < 1 {
            return self
        }

        // If width > height (wide image), letterbox vertically
        if size.width > size.height {
            let squareSize = CGSize(width: minDimension, height: minDimension)
            let renderer = UIGraphicsImageRenderer(size: squareSize)
            return renderer.image { context in
                // Fill with transparent background
                UIColor.clear.setFill()
                context.fill(CGRect(origin: .zero, size: squareSize))

                // Draw image centered
                let x = (squareSize.width - size.width) / 2
                let y = (squareSize.height - size.height) / 2
                self.draw(at: CGPoint(x: x, y: y))
            }
        } else {
            // Height > width (tall image), letterbox horizontally
            let squareSize = CGSize(width: minDimension, height: minDimension)
            let renderer = UIGraphicsImageRenderer(size: squareSize)
            return renderer.image { context in
                // Fill with transparent background
                UIColor.clear.setFill()
                context.fill(CGRect(origin: .zero, size: squareSize))

                // Draw image centered
                let x = (squareSize.width - size.width) / 2
                let y = (squareSize.height - size.height) / 2
                self.draw(at: CGPoint(x: x, y: y))
            }
        }
    }

    /// Resize to maxDimension on the longest side, maintaining aspect ratio.
    func resizedForUpload(maxDimension: CGFloat = 1200) -> UIImage {
        let size = self.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return self }
        let scale = maxDimension / longest
        let newSize = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
