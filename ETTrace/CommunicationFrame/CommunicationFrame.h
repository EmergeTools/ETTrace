//
//  CommunicationFrame.h
//  CommunicationFrame
//
//  Created by Itay Brenner on 6/3/23.
//

#import <Foundation/Foundation.h>
#include <stdint.h>

//! Project version number for CommunicationFrame.
FOUNDATION_EXPORT double CommunicationFrameVersionNumber;

//! Project version string for CommunicationFrame.
FOUNDATION_EXPORT const unsigned char CommunicationFrameVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <CommunicationFrame/PublicHeader.h>


static const int PTPortNumber = 3116;

static const int PTNoFrameTag = 0;

// Use 1MB as max size to transfer
static const int PTMaxChunkSize = 1024 * 1024;

enum {
    // Perf
    PTFrameTypeStart = 101,
    PTFrameTypeStop = 102,
    PTFrameTypeReportCreated = 103,
    PTFrameTypeRequestResults = 104,
    
    // Both
    PTFrameTypeResultsMetadata = 105,
    PTFrameTypeResultsData = 106,
    PTFrameTypeResultsTransferComplete = 107,
    
    // Memory
    PTFrameTypeStartMemory = 108,
    PTFrameTypeStopMemory = 109,
    PTFrameTypeReportCreatedMemory = 110,
    PTFrameTypeRequestResultsMemory = 111,
};

typedef struct _PTStartFrame {
    bool runAtStartup;
} PTStartFrame;

typedef struct _PTMetadataFrame {
    uint64_t fileSize;
} PTMetadataFrame;
