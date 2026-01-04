//
//  ContentView.swift
//  scio
//
//  Created by John Matthew Weston on 6/9/25.
//

import SwiftUI
import UniformTypeIdentifiers
import opencv2 //OpenCV

import CxxStdlib

struct ContentView: View {
    @State private var selectedImage: NSImage?
    @State private var processedImage: NSImage?
    @State private var isShowingFilePicker = false
    @State private var dragOver = false
    @State private var showOriginal = true
    
    @State private var selectedFile: URL?
    
    var body: some View {

        ImageFilterView()

        VStack(spacing: 20) {
            // Header
            Text("Image Viewer")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)
            
            // Main content area
            ZStack {
                // Drop zone background
                RoundedRectangle(cornerRadius: 12)
                    .fill(dragOver ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                    .stroke(
                        dragOver ? Color.blue : Color.gray.opacity(0.3),
                        style: StrokeStyle(lineWidth: 2, dash: [5])
                    )
                    .frame(minWidth: 400, minHeight: 300)
                
                if let image = selectedImage {
                    // Display the selected image
                    let displayImage = showOriginal ? image : (processedImage ?? image)
                    
                    Image(nsImage: displayImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 600, maxHeight: 400)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(radius: 5)
                } else {
                    // Placeholder content
                    VStack(spacing: 15) {
                        Image(systemName: "photo")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Text("Drop an image here or click to select")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Supports: JPG, PNG, GIF, BMP, TIFF")
                            .font(.caption)
                            .foregroundColor(.gray) //.tertiary
                    }
                }
            }
            .onTapGesture {
                isShowingFilePicker = true
            }
            .onDrop(of: [UTType.image], isTargeted: $dragOver) { providers in
                handleDrop(providers: providers)
            }

            // Control buttons
            HStack(spacing: 20) {
                Button("Select Image") {
                    isShowingFilePicker = true
                }
                .buttonStyle(.borderedProminent)
                
                if selectedImage != nil {
                    Button("Apply Edge Detection") {
                        processedImage = ImageFilterProvider.processImage( image: selectedImage!, type: .blur )
                    }
                    .buttonStyle(.bordered)
                    
                    if processedImage != nil {
                        Button(showOriginal ? "Show Processed" : "Show Original") {
                            showOriginal.toggle()
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Button("Clear") {
                        selectedImage = nil
                        processedImage = nil
                        showOriginal = true
                    }
                    .buttonStyle(.bordered)
                }
                Button("Read Data File") {
                    let fileName = "~/Downloads/sub-001_ses-t1_task-resteyesc_eeg.edf"
                    let provider = EDFFormatProvider()
                    provider.readFile(url: URL(fileURLWithPath: fileName))
                }
                .buttonStyle(.bordered)
            }
            .padding(.bottom)
        }
        .padding()
        .frame(minWidth: 500, minHeight: 400)
        .fileImporter(
            isPresented: $isShowingFilePicker,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result: result)
        }
    }
    
    private func handleFileSelection(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            loadImage(from: url)
        case .failure(let error):
            print("File selection error: \(error.localizedDescription)")
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { item, error in
            if let error = error {
                print("Drop error: \(error.localizedDescription)")
                return
            }
            
            DispatchQueue.main.async {
                if let url = item as? URL {
                    loadImage(from: url)
                } else if let data = item as? Data {
                    selectedImage = NSImage(data: data)
                    processedImage = nil // Reset processed image
                    showOriginal = true
                }
            }
        }
        
        return true
    }
    
    private func loadImage(from url: URL) {
        do {
            let imageData = try Data(contentsOf: url)
            selectedImage = NSImage(data: imageData)
            processedImage = nil // Reset processed image when loading new image
            showOriginal = true
        } catch {
            print("Failed to load image: \(error.localizedDescription)")
        }
    }
    
}
