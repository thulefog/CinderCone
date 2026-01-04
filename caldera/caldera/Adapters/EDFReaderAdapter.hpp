//
//  EDFReaderAdapter.hpp
//  Caldera
//
//  Created by John Matthew Weston on 12/3/25.
//

#ifndef EDFReaderAdapter_hpp
#define EDFReaderAdapter_hpp

#if defined __cplusplus

#include <stdio.h>
#include <stdlib.h>

#include <iostream>
#include <optional>
#include <string>

#include "EDFReader.hpp"

class EDFReaderAdapter {
public:
    EDFReaderAdapter() {}
    
    void read( std::string fileName );
    
};

#endif /* __cplusplus */

#endif /* EDFReaderAdapter_hpp */
