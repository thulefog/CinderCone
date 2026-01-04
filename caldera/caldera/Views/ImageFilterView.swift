//
//  ImageFilterView.swift
//
//  Created by John Matthew Weston on 9/30/25.
//

import SwiftUI

enum ProcessingType: String, CaseIterable {
    case original = "Original"
    case blur = "Blur"
    case edges = "Edge Detection"
    case grayscale = "Grayscale"
    case sharpen = "Sharpen"
}

// MARK: ImageFilterView

struct ImageFilterView: View {
#if os(macOS)
    @State private var selectedImage: NSImage?
    @State private var processedImage: NSImage?
    private var displayImage: NSImage? {
        switch processingType {
        case .original:
            return selectedImage
        default:
            return processedImage ?? selectedImage
        }
    }
#else // iOS
    @State private var selectedImage: UIImage?
    @State private var processedImage: UIImage?
    private var displayImage: UIImage? {
        switch processingType {
        case .original:
            return selectedImage
        default:
            return processedImage ?? selectedImage
        }
    }
#endif
    
    @State private var showingImagePicker = false
    @State private var processingType: ProcessingType = .original

    private var provider = ImageFilterProvider()


    
    var body: some View {
        
        VStack {
            // Image Display Area
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 400)
                
                if let image = displayImage {
#if os(macOS)
                    Image(nsImage: displayImage!)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 600, maxHeight: 400)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(radius: 5)
#else // iOS
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 380)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
#endif
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
                        if let image = selectedImage {
                            processedImage = ImageFilterProvider.processImage( image: image, type: processingType )
                        }
                    }
                }
                Spacer()
            } // image selected...
            
        } // vstack
        
#if os(macOS)
        .fileImporter(
            isPresented: $showingImagePicker,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result: result)
        }
#else // iOS
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $selectedImage)
                .onDisappear {
                    if selectedImage != nil {
                        if let image = selectedImage {
                            processedImage = ImageFilterProvider.processImage( image: image, type: processingType )
                            //{_ in }
                        }
                    } // image selected...
                }
        }
#endif
    } // view  - body
    
    
#if os(macOS)

    private func handleFileSelection(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            loadImage(from: url)
        case .failure(let error):
            print("File selection error: \(error.localizedDescription)")
        }
    }
    
    private func loadImage(from url: URL) {
        do {
            let imageData = try Data(contentsOf: url)
            selectedImage = NSImage(data: imageData)
            processedImage = nil // Reset processed image when loading new image
            //..? showOriginal = true
        } catch {
            print("Failed to load image: \(error.localizedDescription)")
        }
    }
#endif
}


