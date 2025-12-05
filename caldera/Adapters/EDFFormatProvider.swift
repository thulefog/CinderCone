//
//  EDFFormatProvider.swift
//  Caldera
//
//  Created by John Matthew Weston on 12/4/25.
//

import Foundation

class EDFFormatProvider {
    func readFile(url: URL) {
        var reader = EDFReaderAdapter()
        reader.read( std.string(url.absoluteString))
    }
}
