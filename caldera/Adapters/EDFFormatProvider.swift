//
//  EDFFormatProvider.swift
//  Caldera
//
//  Created by John Matthew Weston on 12/4/25.
//

import Foundation

/*
 TODO: revisit Document UTI wireup in context of bundle sandbox file I/O permissions
 
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


class EDFFormatProvider {
    func readFile(url: URL) {
        
        do {
            let fileContent = try String(contentsOfFile: url.path(), encoding: .utf8)
            print("File content: \(fileContent)")
        } catch {
            print("Error reading from file: \(error)")
        }
        
        var reader = EDFReaderAdapter()
        reader.read( std.string(url.path()))
    }
}
