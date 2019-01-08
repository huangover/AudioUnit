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
    AUGraph processingGraph;
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
    
    AudioComponentDescription playerDescription;
    playerDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    playerDescription.componentType = kAudioUnitType_Generator;
    playerDescription.componentSubType = kAudioUnitSubType_AudioFilePlayer;
    result = AUGraphAddNode(processingGraph, &playerDescription, &mPlayerNode);
    if (result != noErr) {
        [self printErrorMessage:@"AUGraphAddNode+mPlayerNode" withStatus:result];return;
    }

    result = AUGraphOpen(processingGraph);
    if (result != noErr) {
        [self printErrorMessage:@"AUGraphOpen" withStatus:result];return;
    }
    
    AudioUnit ioUnit;
    result = AUGraphNodeInfo(processingGraph, ioNode, NULL, &ioUnit);
    if (result != noErr) {
        [self printErrorMessage:@"AUGraphNodeInfo+micUnit" withStatus:result];return;
    }
    
    //4-2:获取出PlayerNode的AudioUnit
    result = AUGraphNodeInfo(processingGraph, mPlayerNode, NULL, &mPlayerUnit);
    if (result != noErr) {
        [self printErrorMessage:@"AUGraphNodeInfo+mPlayerUnit" withStatus:result];return;
    }
    
    int enableIO = 1;
    
//    result = AudioUnitSetProperty(ioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &enableIO, sizeof(enableIO));
//    if (result != noErr) {
//        [self printErrorMessage:@"AudioUnitSetProperty+enableIO+micUnit" withStatus:result];return;
//    }
    
    UInt32 bytesPerSample = sizeof(Float32);
    AudioStreamBasicDescription asbd = {0};
    asbd.mSampleRate = 48000.0;//self.mySampleRate;
    asbd.mFormatID = kAudioFormatLinearPCM;
    asbd.mFormatFlags = kAudioFormatFlagIsNonInterleaved | kAudioFormatFlagsNativeFloatPacked;
    asbd.mBytesPerPacket = bytesPerSample;
    asbd.mFramesPerPacket = 1; // defing 1 packet contains only 1 frame
    asbd.mChannelsPerFrame = 2;
    asbd.mBytesPerFrame = bytesPerSample;
    asbd.mBitsPerChannel = 8 * bytesPerSample;

    result = AudioUnitSetProperty(ioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &asbd, sizeof(asbd));
    
    if (result != noErr) {
        [self printErrorMessage:@"AudioUnitSetProperty+streamFormat+micUnit" withStatus:result];return;
    }
    
    result = AudioUnitSetProperty(mPlayerUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  0,
                                  &asbd,
                                  sizeof (asbd)
                                  );
    if (result != noErr) {
        [self printErrorMessage:@"AudioUnitSetProperty+streamFormat+playerUnit" withStatus:result];return;
    }
    
    result = AUGraphConnectNodeInput(processingGraph, mPlayerNode, 0, ioNode, 0);
//    result = AUGraphConnectNodeInput(processingGraph, ioNode, 1, ioNode, 0);
    if (result != noErr) {
        [self printErrorMessage:@"AUGraphConnectNodeInput" withStatus:result];return;
    }
    result = AUGraphInitialize(processingGraph);
    if (result != noErr) {
        [self printErrorMessage:@"AUGraphInitialize" withStatus:result];return;
    }
    
    CAShow(processingGraph);
    
    [self setUpFilePlayer];
    
    result = AUGraphStart(processingGraph);
    if (result != noErr) {
        [self printErrorMessage:@"AUGraphStart" withStatus:result];return;
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

//static void CheckStatus(OSStatus status, NSString *message)
//{
//    if(status != noErr)
//    {
//        char fourCC[16];
//        *(UInt32 *)fourCC = CFSwapInt32HostToBig(status);
//        fourCC[4] = '\0';
//
//        if(isprint(fourCC[0]) && isprint(fourCC[1]) && isprint(fourCC[2]) && isprint(fourCC[3]))
//            NSLog(@"%@: %s", message, fourCC);
//        else
//            NSLog(@"%@: %d", message, (int)status);
//
//        exit(-1);
//    }
//}

- (void) setUpFilePlayer;
{
    NSString *pathString = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"sound.m4a"];
    NSURL *url = [NSURL URLWithString:pathString];
    
    OSStatus status = noErr;
    AudioFileID musicFile;
    CFURLRef songURL = (__bridge  CFURLRef) url;
    // open the input audio file
    status = AudioFileOpenURL(songURL, kAudioFileReadPermission, 0, &musicFile);
    if (status != noErr) {
        [self printErrorMessage:@"Open AudioFile... " withStatus:status];
        return;
    }
    
    
    // tell the file player unit to load the file we want to play
    status = AudioUnitSetProperty(mPlayerUnit, kAudioUnitProperty_ScheduledFileIDs,
                                  kAudioUnitScope_Global, 0, &musicFile, sizeof(musicFile));
    if (status != noErr) {
        [self printErrorMessage:@"Tell AudioFile Player Unit Load Which File" withStatus:status];return;}
    
    AudioStreamBasicDescription fileASBD;
    // get the audio data format from the file
    UInt32 propSize = sizeof(fileASBD);
    status = AudioFileGetProperty(musicFile, kAudioFilePropertyDataFormat,
                                  &propSize, &fileASBD);
    if (status != noErr) {
        [self printErrorMessage:@"get the audio data format from the file... " withStatus:status];return;}
    
    UInt64 nPackets;
    UInt32 propsize = sizeof(nPackets);
    AudioFileGetProperty(musicFile, kAudioFilePropertyAudioDataPacketCount,
                         &propsize, &nPackets);
    // tell the file player AU to play the entire file
    ScheduledAudioFileRegion rgn;
    memset (&rgn.mTimeStamp, 0, sizeof(rgn.mTimeStamp));
    rgn.mTimeStamp.mFlags = kAudioTimeStampSampleTimeValid;
    rgn.mTimeStamp.mSampleTime = 0;
    rgn.mCompletionProc = NULL;
    rgn.mCompletionProcUserData = NULL;
    rgn.mAudioFile = musicFile;
    rgn.mLoopCount = 0;
    rgn.mStartFrame = 0;
    rgn.mFramesToPlay = (UInt32)nPackets * fileASBD.mFramesPerPacket;
    status = AudioUnitSetProperty(mPlayerUnit, kAudioUnitProperty_ScheduledFileRegion,
                                  kAudioUnitScope_Global, 0,&rgn, sizeof(rgn));
    if (status != noErr) {
        [self printErrorMessage:@"Set Region... " withStatus:status];return;}
    
    
    // prime the file player AU with default values
    UInt32 defaultVal = 0;
    status = AudioUnitSetProperty(mPlayerUnit, kAudioUnitProperty_ScheduledFilePrime,
                                  kAudioUnitScope_Global, 0, &defaultVal, sizeof(defaultVal));
    if (status != noErr) {
        [self printErrorMessage:@"Prime Player Unit With Default Value... " withStatus:status];return;}
    
    
    // tell the file player AU when to start playing (-1 sample time means next render cycle)
    AudioTimeStamp startTime;
    memset (&startTime, 0, sizeof(startTime));
    startTime.mFlags = kAudioTimeStampSampleTimeValid;
    startTime.mSampleTime = -1;
    status = AudioUnitSetProperty(mPlayerUnit, kAudioUnitProperty_ScheduleStartTimeStamp,
                                  kAudioUnitScope_Global, 0, &startTime, sizeof(startTime));
    if (status != noErr) {
        [self printErrorMessage:@"set Player Unit Start Time... " withStatus:status];return;}
}

@end
