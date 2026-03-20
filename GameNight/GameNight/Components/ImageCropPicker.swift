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
                // Resize to max 1200px on longest side to keep uploads reasonable
                parent.onImagePicked(image.resizedForUpload())
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
    }
}

extension UIImage {
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
