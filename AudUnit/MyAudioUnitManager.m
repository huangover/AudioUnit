//
//  MyAudioUnitManager.m
//  FFmpegDecoder
//
//  Created by sihang huang on 2018/12/30.
//  Copyright © 2018 xiaokai.zhan. All rights reserved.
//

#import "MyAudioUnitManager.h"
#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVFoundation.h>

@interface MyAudioUnitManager()
@property (nonatomic, assign) double mySampleRate;
@end

@implementation MyAudioUnitManager
{
    AUGraph processingGraph;
    AudioUnit ioUnit;
    
    AUNode                                      mPlayerNode;
    AudioUnit                                   mPlayerUnit;
}

- (void)constructUnits {
    /*
     1. configure audio session
     2. specify audio unit
     3. create graph, initialize audio unit(aunode)
     4. configure audio units
     5. connect audio unit nodes
     6. provide user interface
     7. start the graph
     */
    self.mySampleRate = 44100;
    
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *error;
    [session setPreferredSampleRate:self.mySampleRate error:&error];
    if (error) {
        NSLog(@"failed to set sample rate on AVAudioSession");
        return;
    }
    [session setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
    if (error) {
        NSLog(@"failed to set category on AVAudioSession");
        return;
    }
    [session setPreferredIOBufferDuration:0.0002 error:&error];
    if (error) {
        NSLog(@"failed to set io buffer duration on AVAuioSession");
        return;
    }
    [session setActive:YES error:&error];
    if (error) {
        NSLog(@"failed to activate AVAudioSession");
        return;
    }
    self.mySampleRate = session.sampleRate;
    
    AudioComponentDescription description;
    description.componentType = kAudioUnitType_Output;
    description.componentSubType = kAudioUnitSubType_RemoteIO;
    description.componentManufacturer = kAudioUnitManufacturer_Apple;
    
    OSStatus result = noErr;
    result = NewAUGraph(&processingGraph);
    if (result != noErr) {
        [self printErrorMessage:@"NewAUGraph" withStatus:result];
        return;
    }
    
    AUNode ioNode;
    result = AUGraphAddNode(processingGraph, &description, &ioNode);
    if (result != noErr) {
        [self printErrorMessage:@"AUGraphAddNode+ioNode" withStatus:result];return;
    }
    
    result = AUGraphOpen(processingGraph);
    if (result != noErr) {
        [self printErrorMessage:@"AUGraphOpen" withStatus:result];return;
    }
    
    result = AUGraphNodeInfo(processingGraph, ioNode, NULL, &ioUnit);
    if (result != noErr) {
        [self printErrorMessage:@"AUGraphNodeInfo+micUnit" withStatus:result];return;
    }
    
    // 打开mic
    int enableIO = 1;
    result = AudioUnitSetProperty(ioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &enableIO, sizeof(enableIO));
    if (result != noErr) {
        [self printErrorMessage:@"AudioUnitSetProperty+enableIO+micUnit" withStatus:result];return;
    }
    
    AudioStreamBasicDescription asbd = {0};
    int channels = 2;
    UInt32 bytesPerSample = sizeof(Float32);
    asbd.mSampleRate = self.mySampleRate;
    // Yes, I know you probably want floating point samples, but the iPhone isn't going
    // to give you floating point data. You'll need to make the conversion by hand from
    // linear PCM <-> float.
    asbd.mFormatID = kAudioFormatLinearPCM;
    asbd.mFormatFlags = kAudioFormatFlagsNativeFloatPacked;
    asbd.mChannelsPerFrame = channels; // 1 for mono. 2 for stereo.

    asbd.mFramesPerPacket = 1;
    asbd.mBytesPerFrame = channels * bytesPerSample;
    asbd.mBytesPerPacket = channels * bytesPerSample;
    asbd.mBitsPerChannel = 8 * bytesPerSample;

    
//    // You might want to replace this with a different value, but keep in mind that the
//    // iPhone does not support all sample rates. 8kHz, 22kHz, and 44.1kHz should all work.
//    asbd.mSampleRate = 44100;

//    asbd.mFormatID = kAudioFormatLinearPCM;
//    // This part is important!
//    asbd.mFormatFlags = kAudioFormatFlagIsSignedInteger |
//    kAudioFormatFlagsNativeEndian |
//    kAudioFormatFlagIsPacked;
//    // Not sure if the iPhone supports recording >16-bit audio, but I doubt it.
//    asbd.mBitsPerChannel = 16;
//    // 1 sample per frame, will always be 2 as long as 16-bit samples are being used
//    asbd.mBytesPerFrame = 2;
//    // Record in mono. Use 2 for stereo, though I don't think the iPhone does true stereo recording
//    asbd.mChannelsPerFrame = 1;
//    asbd.mBytesPerPacket = asbd.mBytesPerFrame *
//    asbd.mChannelsPerFrame;
//    // Always should be set to 1
//    asbd.mFramesPerPacket = 1;
//    // Always set to 0, just to be sure
//    asbd.mReserved = 0;
    
    
    result = AudioUnitSetProperty(ioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &asbd, sizeof(asbd));
    if (result != noErr) {
        [self printErrorMessage:@"AudioUnitSetProperty+streamFormat+micUnit" withStatus:result];return;
    }
    result = AudioUnitSetProperty(ioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &asbd, sizeof(asbd));
    if (result != noErr) {
        [self printErrorMessage:@"AudioUnitSetProperty+streamFormat+speakerUnit" withStatus:result];return;
    }

    result = AUGraphConnectNodeInput(processingGraph, ioNode, 1, ioNode, 0);
    if (result != noErr) {
        [self printErrorMessage:@"AUGraphConnectNodeInput" withStatus:result];return;
    }
    
    result = AUGraphInitialize(processingGraph);
    if (result != noErr) {
        [self printErrorMessage:@"AUGraphInitialize" withStatus:result];return;
    }
    
    CAShow(processingGraph);
    
}

- (void) start {
    OSStatus result = noErr;
    result = AUGraphStart(processingGraph);
    if (result != noErr) {
        [self printErrorMessage:@"AUGraphStart" withStatus:result];return;
    }
}

- (void) stop {
    OSStatus result = noErr;
    result = AUGraphStop(processingGraph);
    if (result != noErr) {
        [self printErrorMessage:@"AUGraphStop" withStatus:result];return;
    }
}

- (void) printErrorMessage: (NSString *) errorString withStatus: (OSStatus) result {
    
    char resultString[5];
    UInt32 swappedResult = CFSwapInt32HostToBig (result);
    bcopy (&swappedResult, resultString, 4);
    resultString[4] = '\0';
    
    NSLog (
           @"*** %@ error: %d %08X %4.4s\n",
           errorString,
           (char*) &resultString
           );
}

@end
