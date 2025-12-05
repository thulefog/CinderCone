//
//  EDFReaderAdapter.cpp
//  Caldera
//
//  Created by John Matthew Weston on 12/3/25.
//

#include "EDFReaderAdapter.hpp"

void EDFReaderAdapter::read( std::string fileName ) {
    std::cout << __FUNCTION__ << std::endl;

    edf_file_read();
};
