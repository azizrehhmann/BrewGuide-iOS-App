import SwiftUI
import AVFoundation

struct BeanScannerView: View {
    @ObservedObject var viewModel: BeanFirstViewModel
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var showPhotoPicker = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "camera.viewfinder")
                .font(.system(size: 64, weight: .ultraLight, design: .rounded))
                .foregroundStyle(Constants.Colors.accentGold)

            VStack(spacing: 8) {
                Text("Scan Your Coffee Bag")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(Constants.Colors.primaryColor)

                Text("Take a photo of the label or choose from your library")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            VStack(spacing: 12) {
                Button {
                    showCamera = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                        Text("Take Photo")
                    }
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous)
                            .fill(Constants.Colors.accentGold)
                    )
                }

                Button {
                    showPhotoPicker = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle")
                        Text("Choose from Library")
                    }
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(Constants.Colors.accentGold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius, style: .continuous)
                            .strokeBorder(Constants.Colors.accentGold.opacity(0.3), lineWidth: 1.5)
                    )
                }
            }
            .padding(.horizontal, Constants.Layout.horizontalPadding)

            Button("Cancel") {
                viewModel.goBack()
            }
            .font(.system(.body, design: .rounded))
            .foregroundStyle(.secondary)

            Spacer()
        }
        .adaptiveBackground()
        .sheet(isPresented: $showCamera) {
            ImagePickerView(sourceType: .camera) { image in
                viewModel.handleCapturedImage(image)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showPhotoPicker) {
            ImagePickerView(sourceType: .photoLibrary) { image in
                viewModel.handleCapturedImage(image)
            }
        }
    }
}

// MARK: - UIKit Image Picker

struct ImagePickerView: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImageCaptured: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImageCaptured: onImageCaptured)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImageCaptured: (UIImage) -> Void

        init(onImageCaptured: @escaping (UIImage) -> Void) {
            self.onImageCaptured = onImageCaptured
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            picker.dismiss(animated: true)
            if let image = info[.originalImage] as? UIImage {
                onImageCaptured(image)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
