//
//  ImageFilterView.swift
//
//  Created by John Matthew Weston on 9/30/25.
//

import SwiftUI

struct ImageFilterView: View {
    @State private var selectedImage: UIImage?
    @State private var processedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var processingType: ProcessingType = .original

    private var provider = ImageFilterProvider()

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
                        if let image = selectedImage {
                            processedImage = ImageFilterProvider.processImage( image, type: processingType )
                            //selectedImage = processedImage
                            //{_ in }
                        }
                    }
                }
                Spacer()
            } // image selected...
            
        } // vstack
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Menu {
                    Button(action: {
                        // TODO: ....
                    }) {
                        Label("Step One", systemImage: "perspective")
                    } // button
                    Divider()
                    Button(action: {
                        // TODO: ....
                    }) {
                        Label("Step Two", systemImage: "perspective")
                    } // button
                    
                } label: {
                    Label("toolbar", systemImage: "mountain.2")
                }
            } // toolbaritem
        } // toolbar
        .onAppear(perform: {
            /* OPEN: trace 
            if let provider = provider {
                provider.loadModel()
            }
             */
        })
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $selectedImage)
                .onDisappear {
                    if selectedImage != nil {
                        if let image = selectedImage {
                            processedImage = ImageFilterProvider.processImage( image, type: processingType )
                            //{_ in }
                        }
                    } // image selected...
                }
        }
    }
}
