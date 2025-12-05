//
//  Widgets.swift
//  Caldera
//
//  Created by John Matthew Weston on 12/4/25.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
      static let edfDocument = UTType(importedAs: "co.aquavit.edf-document", conformingTo: .data)
  }

/*
NavigationView {
    VStack{
        NavigationLink(destination: FilePickerView(selectedFileURL: $selectedFile)) {
            Text("Select Data File")
        }
    }
}
 ...
 Button("Read Data File") {

     if let file = selectedFile {
         Text("File selected in parent: \(file.lastPathComponent)")
             .padding()
     }
     
     var adapter = EDFReaderAdapter()
     if let fileName = $selectedFile.wrappedValue?.absoluteString {
         adapter.read( std.string(fileName)  )
     }
 }
 .buttonStyle(.bordered)
 */

struct FilePickerView: View {
    @Binding var selectedFileURL: URL?
    @State private var isImporting = false
    @State private var fileContent: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Button("Select File") {
                isImporting = true
            }
            .buttonStyle(.borderedProminent)
            
            if let url = selectedFileURL {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Selected File:")
                        .font(.headline)
                    Text(url.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !fileContent.isEmpty {
                        ScrollView {
                            Text(fileContent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .frame(maxHeight: 200)
                    }
                }
                .padding()
            }
        }
        .frame(width: 500, height: 400)
        .padding()
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.text, .plainText, .edfDocument],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                selectedFileURL = url
                
                // Read file content (for text files)
                if url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }
                    
                    do {
                        fileContent = try String(contentsOf: url, encoding: .utf8)
                    } catch {
                        fileContent = "Error reading file: \(error.localizedDescription)"
                    }
                }
                
            case .failure(let error):
                print("File selection error: \(error.localizedDescription)")
            }
        }
    }
}
