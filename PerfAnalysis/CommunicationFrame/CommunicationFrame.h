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

enum {
    PTFrameTypeStart = 101,
    PTFrameTypeStop = 102,
    PTFrameTypePing = 103,
    PTFrameTypePong = 104,
};

typedef struct _PTStartFrame {
    bool runAtStartup;
} PTStartFrame;
