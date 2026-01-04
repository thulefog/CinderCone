//
//  ClassificationView.swift
//
//  Created by John Matthew Weston on 9/30/25.
//

import SwiftUI


// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

struct ClassificationView: View {
    @State private var selectedImage: UIImage?
    @State private var processedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var processingType: ProcessingType = .original

    private var provider: GenericClassificationProvider?
    
    private var displayImage: UIImage? {
        switch processingType {
        case .original:
            return selectedImage
        default:
            return processedImage ?? selectedImage
        }
    }
    
    var body: some View {
        
        VStack {
            // Image Display Area
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 400)
                
                if let image = displayImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 380)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    VStack {
                        Image(systemName: "photo")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("Tap to select an image")
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                }
            }
            .onTapGesture {
                showingImagePicker = true
            }
            
            // Processing Type Picker
            if selectedImage != nil {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Processing Options")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    Picker("Processing Type", selection: $processingType) {
                        ForEach(ProcessingType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    .onChange(of: processingType) { _ in
                        if let provider = provider,
                           let image = selectedImage {
                            provider.processImage( image ) {_ in
                            }
                        }
                    }
                }
                
                Spacer()
            } // vstack
        } // view - body
        .onAppear(perform: {
            if let provider = provider {
                provider.loadModel()
            }
        })
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $selectedImage)
                .onDisappear {
                    if selectedImage != nil {
                        if let provider = provider,
                           let image = selectedImage {
                            provider.processImage( image ) {_ in
                            }
                        }
                    } // image selected...
                }
        }
    }
}

enum ProcessingType: String, CaseIterable {
    case original = "Original"
    case blur = "Blur"
    case edges = "Edge"
    case grayscale = "Grayscale"
    case sharpen = "Sharpen"
}
