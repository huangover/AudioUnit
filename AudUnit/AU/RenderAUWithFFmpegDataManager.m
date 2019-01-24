//
//  MyAudioUnitManagerCallback.m
//  AudUnit
//
//  Created by Sihang Huang on 1/15/19.
//  Copyright © 2019 sihang huang. All rights reserved.
//

#import "RenderAUWithFFmpegDataManager.h"
#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVFoundation.h>

@interface RenderAUWithFFmpegDataManager()
@property (nonatomic, strong) NSInputStream *stream;
@property(nonatomic, assign) AUNode             convertNode;
@property(nonatomic, assign) AudioUnit          convertUnit;
@property (nonatomic, assign) int myNumChannels;
@property (nonatomic, assign) double mySampleRate;

@end

@implementation RenderAUWithFFmpegDataManager
{
    OSStatus result;
    AUGraph processingGraph;
    
    AudioUnit ioUnit;
    AUNode ioNode;
    
    AudioUnit ipodEffectUnit;
    AUNode ipodEffectNode;
    CFArrayRef mEQPresetsArray;
    
    AUNode mPlayerNode;
    AudioUnit mPlayerUnit;
    NSURL *_playPath;
    
    AUNode mixerNode;
    AudioUnit mixerUnit;
    
    SInt16 *_outData;
}

- (int)myNumChannels {
    
    if ([self.delegate respondsToSelector:@selector(numOfChannelsForManager:)]) {
        return [self.delegate numOfChannelsForManager:self];
    }
    
    return 1;
}

- (double)mySampleRate {
    if ([self.delegate respondsToSelector:@selector(sampleRateForManager:)]) {
        return [self.delegate sampleRateForManager:self];
    }
    
    return 44100;
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
    
    _outData = (SInt16 *)calloc(8192, sizeof(SInt16));
    
    [self setUpAudioSession];
    [self newGraph];
    [self openGraph];
    [self setUpIOUnit];
    [self connectNodes];
    [self initGraph];
}

- (void)setUpAudioSession {
    
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
//    self.mySampleRate = session.sampleRate;
}

- (void)newGraph {
    result = NewAUGraph(&processingGraph);
    if (result != noErr) {
        [self printErrorMessage:@"NewAUGraph" withStatus:result];
        return;
    }
}

- (void)openGraph {
    result = AUGraphOpen(processingGraph);
    if (result != noErr) {
        [self printErrorMessage:@"AUGraphOpen" withStatus:result];return;
    }
}

- (void)setUpIOUnit {
    
    AudioComponentDescription description;
    description.componentType = kAudioUnitType_Output;
    description.componentSubType = kAudioUnitSubType_RemoteIO;
    description.componentManufacturer = kAudioUnitManufacturer_Apple;
    
    result = AUGraphAddNode(processingGraph, &description, &ioNode);
    if (result != noErr) {
        [self printErrorMessage:@"AUGraphAddNode+ioNode" withStatus:result];return;
    }
    
    result = AUGraphNodeInfo(processingGraph, ioNode, NULL, &ioUnit);
    if (result != noErr) {
        [self printErrorMessage:@"AUGraphNodeInfo+ioNode" withStatus:result];return;
    }
    
    int _channels = self.myNumChannels;
    UInt32 bytesPerSample = sizeof (SInt16);
    
    AudioStreamBasicDescription asbd = {0};
    asbd.mFormatID          = kAudioFormatLinearPCM;
    asbd.mFormatFlags       = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    asbd.mBytesPerPacket    = bytesPerSample * _channels;
    asbd.mFramesPerPacket   = 1;
    asbd.mBytesPerFrame     = bytesPerSample * _channels;
    asbd.mChannelsPerFrame  = _channels;
    asbd.mBitsPerChannel    = 8 * bytesPerSample;
    asbd.mSampleRate        = self.mySampleRate;
    
    if (AudioUnitSetProperty(ioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &asbd, sizeof(asbd)) != noErr) {
        [self printErrorMessage:@"AudioUnitSetProperty+streamFormat+ioUnit" withStatus:result];return;
    }
}

static OSStatus SpeakerRenderCallback (
                                    void                        *inRefCon,
                                    AudioUnitRenderActionFlags  *ioActionFlags,
                                    const AudioTimeStamp        *inTimeStamp,
                                    UInt32                      inBusNumber,
                                    UInt32                      inNumberFrames,
                                    AudioBufferList             *ioData
                                    )
{
    for (int i=0;i<ioData->mNumberBuffers;i++) {
        memset(ioData->mBuffers[i].mData, 0, ioData->mBuffers[i].mDataByteSize);
    }

    RenderAUWithFFmpegDataManager *manager = (__bridge RenderAUWithFFmpegDataManager *)inRefCon;
    
    
    if ([manager.delegate respondsToSelector:@selector(renderAUWithFFmpegDataManager:fillBuffer:withSize:)]) {
        [manager.delegate renderAUWithFFmpegDataManager:manager fillBuffer:manager->_outData withSize:inNumberFrames * manager.myNumChannels];
        
        for (int i=0;i<ioData->mNumberBuffers;i++) {
            memcpy((SInt16 *)ioData->mBuffers[i].mData, manager->_outData, inNumberFrames *  manager.myNumChannels * 2);
        }
    }
    
    return noErr;
    
}

- (void)connectNodes {
    AURenderCallbackStruct callback;
    callback.inputProcRefCon = (__bridge void *)self;
    callback.inputProc = &SpeakerRenderCallback;
    if (AUGraphSetNodeInputCallback(processingGraph, ioNode, 0, &callback) != noErr) {
        [self printErrorMessage:@"AudioUnitSetProperty+ speaker callback + failed" withStatus:result];return;
    }
    
    Boolean graphUpdated;
    if (AUGraphUpdate(processingGraph, &graphUpdated) != noErr) {
        [self printErrorMessage:@"AUGraphUpdate+ add speaker callback + failed" withStatus:result];return;
    }
    
    result = AUGraphInitialize(processingGraph);
    if (result != noErr) {
        [self printErrorMessage:@"AUGraphInitialize" withStatus:result];return;
    }
}

- (void)initGraph {
    result = AUGraphInitialize(processingGraph);
    if (result != noErr) {
        [self printErrorMessage:@"AUGraphInitialize" withStatus:result];return;
    }
}

- (void) start {
    result = AUGraphStart(processingGraph);
    if (result != noErr) {
        [self printErrorMessage:@"AUGraphStart" withStatus:result];return;
    }
}

- (void) stop {
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
