//
//  EMGChannelListener.m
//  PerfAnalysis
//
//  Created by Itay Brenner on 6/3/23.
//

#import "EMGChannelListener.h"
#import <PeerTalk/PTChannel.h>
#import <CommunicationFrame/CommunicationFrame.h>
#import "EMGPerfAnalysis_Private.h"

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
    } else if (type != PTFrameTypeStart && type != PTFrameTypeStop) {
        NSLog(@"Unexpected frame of type %u", type);
        [channel close];
        return NO;
    } else {
        return YES;
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
    } else if (type == PTFrameTypePing && self.peerChannel) {
        [self.peerChannel sendFrameOfType:PTFrameTypePong tag:tag withPayload:nil callback:nil];
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

@end
