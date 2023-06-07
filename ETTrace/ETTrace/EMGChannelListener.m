//
//  EMGChannelListener.m
//  PerfAnalysis
//
//  Created by Itay Brenner on 6/3/23.
//

#import "EMGChannelListener.h"
#import "EMGPerfAnalysis_Private.h"
//@import Peertalk;
// @import CommunicationFrame;
#import <Peertalk.h>
#import <CommunicationFrame.h>

@interface EMGChannelListener () <PTChannelDelegate>
@property (nonatomic, weak) PTChannel *serverChannel;
@property (nonatomic, weak) PTChannel *peerChannel;
@end

@implementation EMGChannelListener
- (instancetype) init {
    self = [super init];
    if (self)
    {
        [self setupChannel];
    }
    return self;
}

- (void) setupChannel {
    PTChannel *channel = [PTChannel channelWithDelegate:self];
    [channel listenOnPort:PTPortNumber IPv4Address:INADDR_LOOPBACK callback:^(NSError *error) {
    if (error) {
        NSLog(@"Failed to listen on 127.0.0.1:%d: %@", PTPortNumber, error);
    } else {
        NSLog(@"Listening on 127.0.0.1:%d", PTPortNumber);
        self.serverChannel = channel;
    }
    }];
}

#pragma mark - PTChannelDelegate

- (BOOL)ioFrameChannel:(PTChannel*)channel shouldAcceptFrameOfType:(uint32_t)type tag:(uint32_t)tag payloadSize:(uint32_t)payloadSize {
    if (channel != self.peerChannel) {
        // A previous channel that has been canceled but not yet ended. Ignore.
        return NO;
    } else if (type == PTFrameTypeStart || type == PTFrameTypeStop || type == PTFrameTypeRequestResults){
        return YES;
    } else {
        NSLog(@"Unexpected frame of type %u", type);
        [channel close];
        return NO;
    }
}

- (void)ioFrameChannel:(PTChannel*)channel didReceiveFrameOfType:(uint32_t)type tag:(uint32_t)tag payload:(NSData *)payload {
    if (type == PTFrameTypeStart) {
        PTStartFrame *startFrame = (PTStartFrame *)payload.bytes;
        NSLog(@"Start received, with: %i", startFrame->runAtStartup);
        BOOL runAtStartup = startFrame->runAtStartup;
        if (runAtStartup) {
            [EMGPerfAnalysis setupRunAtStartup];
        } else {
            [EMGPerfAnalysis setupStackRecording];
        }
    } else if (type == PTFrameTypeStop) {
        [EMGPerfAnalysis stopRecordingThread];
    } else if (type == PTFrameTypeRequestResults) {
        [self sendReportData];
    }
}

- (void)ioFrameChannel:(PTChannel*)channel didEndWithError:(NSError*)error {
    if (error) {
        NSLog(@"%@ ended with error: %@", channel, error);
    } else {
        NSLog(@"Disconnected from %@", channel.userInfo);
    }
}

- (void)ioFrameChannel:(PTChannel*)channel didAcceptConnection:(PTChannel*)otherChannel fromAddress:(PTAddress*)address {
    if (self.peerChannel) {
        [self.peerChannel cancel];
    }
  
    self.peerChannel = otherChannel;
    self.peerChannel.userInfo = address;
    NSLog(@"Connected to %@", address);
}

- (void) sendReportCreatedMessage {
    NSData *emptyData = [[NSData alloc] init];
    [self.peerChannel sendFrameOfType:PTFrameTypeReportCreated tag:PTFrameNoTag withPayload:emptyData callback:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"Could not send message");
        } else {
            NSLog(@"Message sent");
        }
    }];
}

- (void) sendReportData {
    NSURL *outURL = [EMGPerfAnalysis outputPath];
    
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:outURL.path];
    if (!fileHandle) {
        NSLog(@"Error opening file");
        return;
    }
    
    // Sending metadata
    PTMetadataFrame *frame = CFAllocatorAllocate(nil, sizeof(PTMetadataFrame), 0);
    frame->fileSize = fileHandle.availableData.length;
    dispatch_data_t dataFrame = dispatch_data_create((const void*)frame, sizeof(PTMetadataFrame), nil, ^{
        CFAllocatorDeallocate(nil, frame);
    });
    [self.peerChannel sendFrameOfType:PTFrameTypeResultsMetadata tag:PTFrameNoTag withPayload:dataFrame callback:nil];
    
    [fileHandle seekToFileOffset:0];
    while (YES) {
        NSData *chunk = [fileHandle readDataOfLength:PTMaxChunkSize];
        if (chunk.length == 0) {
            break;
        }
        [self.peerChannel sendFrameOfType:PTFrameTypeResultsData tag:PTFrameNoTag withPayload:chunk callback:nil];
    }
    
    // Confirm file completed
    [self.peerChannel sendFrameOfType:PTFrameTypeResultsTransferComplete tag:PTFrameNoTag withPayload:nil callback:nil];
}

@end
