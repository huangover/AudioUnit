//
//  MyAudioUnitManager.m
//  FFmpegDecoder
//
//  Created by sihang huang on 2018/12/30.
//  Copyright © 2018 xiaokai.zhan. All rights reserved.
//

#import "ConnectAUNodesManager.h"
#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVFoundation.h>
#import "CommonUtil.h"

@interface ConnectAUNodesManager()
@property (nonatomic, assign) double mySampleRate;
@end

@implementation ConnectAUNodesManager
{
    OSStatus result;
    AUGraph processingGraph;
    
    AudioUnit ioUnit;
    AUNode ioNode;
    
    AudioUnit ipodEffectUnit;
    AUNode ipodEffectNode;
    CFArrayRef mEQPresetsArray;
    
    AUNode                                      mPlayerNode;
    AudioUnit                                   mPlayerUnit;
    NSURL*                                      _playPath;
    
    AUNode mixerNode;
    AudioUnit mixerUnit;
    
    ExtAudioFileRef outFileRef;
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
    
    [self setUpAudioSession];
    [self setUpGraph];
    [self setUpIOUnit];
    [self setUpPlayerUnit];
    [self setUpMixerUnit];
    [self setUpEffectUnit];
    [self connectNodes];
    [self initGraph];
    [self setUpPlayerParamsAfterGraphInit];//只有对Graph进行Initialize之后才可以设置AudioPlayer的参数
//    CAShow(processingGraph);
}

- (void)setUpGraph {
    result = NewAUGraph(&processingGraph);
    if (result != noErr) {
        [self printErrorMessage:@"NewAUGraph" withStatus:result];
        return;
    }
}

- (void)setUpAudioSession {
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
    asbd.mFormatFlags = kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved;
    asbd.mChannelsPerFrame = channels; // 1 for mono. 2 for stereo.
    
    asbd.mFramesPerPacket = 1;
    asbd.mBytesPerFrame = bytesPerSample;
    asbd.mBytesPerPacket = bytesPerSample;
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
    // 文档说了，不需要！
    //    result = AudioUnitSetProperty(ioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &asbd, sizeof(asbd));
    //    if (result != noErr) {
    //        [self printErrorMessage:@"AudioUnitSetProperty+streamFormat+speakerUnit" withStatus:result];return;
    //    }
}

- (void) setUpPlayerUnit
{
    OSStatus status = noErr;
    AudioComponentDescription description;
    description.componentType = kAudioUnitType_Generator;
    description.componentSubType = kAudioUnitSubType_AudioFilePlayer;
    description.componentManufacturer = kAudioUnitManufacturer_Apple;
    description.componentFlags = 0;
    description.componentFlagsMask = 0;
    status = AUGraphAddNode(processingGraph, &description, &mPlayerNode);
    if (status != noErr) {
        [self printErrorMessage:@"AUGraphAddNode + playerNode" withStatus:status];return;
    }
    
    status = AUGraphNodeInfo(processingGraph, mPlayerNode, NULL, &mPlayerUnit);
    if (status != noErr) {
        [self printErrorMessage:@"AUGraphNodeInfo + playerUnit" withStatus:status];return;
    }
    
    AudioStreamBasicDescription asbd = {0};
    int channels = 2;
    UInt32 bytesPerSample = sizeof(Float32);
    asbd.mSampleRate = self.mySampleRate;
    asbd.mFormatID = kAudioFormatLinearPCM;
    asbd.mFormatFlags = kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved;
    asbd.mChannelsPerFrame = channels; // 1 for mono. 2 for stereo.
    asbd.mFramesPerPacket = 1;
    asbd.mBytesPerFrame = bytesPerSample;
    asbd.mBytesPerPacket = bytesPerSample;
    asbd.mBitsPerChannel = 8 * bytesPerSample;
    status = AudioUnitSetProperty(mPlayerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &asbd, sizeof(asbd));
    if (status != noErr) {
        [self printErrorMessage:@"set stream format + playerUnit" withStatus:status];return;
    }
}

- (void)setUpPlayerParamsAfterGraphInit {
    
    OSStatus status = noErr;
    
    NSString *path = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"sound.m4a"];
    _playPath = [NSURL URLWithString:path];
    
    AudioFileID musicFile;
    CFURLRef songURL = (__bridge  CFURLRef) _playPath;
    // open the input audio file
    status = AudioFileOpenURL(songURL, kAudioFileReadPermission, 0, &musicFile);
    if (status != noErr) {
        [self printErrorMessage:@"AAudioFileOpenURL" withStatus:status];return;
    }
    
    
    // tell the file player unit to load the file we want to play
    status = AudioUnitSetProperty(mPlayerUnit, kAudioUnitProperty_ScheduledFileIDs,
                                  kAudioUnitScope_Global, 0, &musicFile, sizeof(musicFile));
    if (status != noErr) {
        [self printErrorMessage:@"Tell AudioFile Player Unit Load Which File" withStatus:status];return;
    }
    
    AudioStreamBasicDescription fileASBD;
    // get the audio data format from the file
    UInt32 propSize = sizeof(fileASBD);
    status = AudioFileGetProperty(musicFile, kAudioFilePropertyDataFormat,
                                  &propSize, &fileASBD);
    if (status != noErr) {
        [self printErrorMessage:@"get the audio data format from the file" withStatus:status];return;
    }

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
        [self printErrorMessage:@"Set Region" withStatus:status];return;
    }
    
    // prime the file player AU with default values
    UInt32 defaultVal = 0;
    status = AudioUnitSetProperty(mPlayerUnit, kAudioUnitProperty_ScheduledFilePrime,
                                  kAudioUnitScope_Global, 0, &defaultVal, sizeof(defaultVal));
    if (status != noErr) {
        [self printErrorMessage:@"Prime Player Unit With Default Value" withStatus:status];return;
    }
    
    // tell the file player AU when to start playing (-1 sample time means next render cycle)
    AudioTimeStamp startTime;
    memset (&startTime, 0, sizeof(startTime));
    startTime.mFlags = kAudioTimeStampSampleTimeValid;
    startTime.mSampleTime = -1;
    status = AudioUnitSetProperty(mPlayerUnit, kAudioUnitProperty_ScheduleStartTimeStamp,
                                  kAudioUnitScope_Global, 0, &startTime, sizeof(startTime));
    if (status != noErr) {
        [self printErrorMessage:@"set Player Unit Start Time" withStatus:status];return;
    }
}

- (void)setUpMixerUnit {
    OSStatus status = noErr;
    AudioComponentDescription des;
    des.componentType = kAudioUnitType_Mixer;
    des.componentSubType = kAudioUnitSubType_MultiChannelMixer;
    des.componentManufacturer = kAudioUnitManufacturer_Apple;
    des.componentFlags = 0;
    des.componentFlagsMask = 0;
    status = AUGraphAddNode(processingGraph, &des, &mixerNode);
    if (status != noErr) {
        [self printErrorMessage:@"AUGraphAddNode + mixerNode" withStatus:status];return;
    }
    
    status = AUGraphNodeInfo(processingGraph, mixerNode, NULL, &mixerUnit);
    if (status != noErr) {
        [self printErrorMessage:@"AUGraphNodeInfo + mixerUnit" withStatus:status];return;
    }
    
    // mixer output volumn
    [self setMixerUnitOutputVolumn:0.5];
    
    // mic input volumn
    [self setMicUnitVolumn:2];
    
    // music input volumn
    [self setPlayerUnitVolumn:0.5];
}

- (AudioStreamBasicDescription)effectOutputASBD {
    AudioStreamBasicDescription asbd = {0};
    int channels = 2;
    UInt32 bytesPerSample = sizeof(Float32);
    asbd.mSampleRate = self.mySampleRate;
    asbd.mFormatID = kAudioFormatLinearPCM;
    asbd.mFormatFlags = kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved;
    asbd.mChannelsPerFrame = channels; // 1 for mono. 2 for stereo.
    asbd.mFramesPerPacket = 1;
    asbd.mBytesPerFrame = bytesPerSample;
    asbd.mBytesPerPacket = bytesPerSample;
    asbd.mBitsPerChannel = 8 * bytesPerSample;
    
    return asbd;
}

- (void)setUpEffectUnit {
    AudioComponentDescription des;
    des.componentManufacturer = kAudioUnitManufacturer_Apple;
    des.componentType = kAudioUnitType_Effect;
    des.componentSubType = kAudioUnitSubType_AUiPodEQ;
    
    if(AUGraphAddNode(processingGraph, &des, &ipodEffectNode) != noErr) {
        [self printErrorMessage:@"AUGraphAddNode + ipodEffectNode failed" withStatus:result];return;
    }
    
    if(AUGraphNodeInfo(processingGraph, ipodEffectNode, NULL, &ipodEffectUnit) != noErr) {
        [self printErrorMessage:@"AUGraphNodeInfo + ipodEffectNode failed" withStatus:result];return;
    }
    
    AudioStreamBasicDescription asbd = [self effectOutputASBD];
    if(AudioUnitSetProperty(ipodEffectUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &asbd, sizeof(asbd)) != noErr) {
        [self printErrorMessage:@"set stream format + effect Unit" withStatus:result];return;
    }
    
    UInt32 size = sizeof(mEQPresetsArray);
    AudioUnitGetProperty(ipodEffectUnit, kAudioUnitProperty_FactoryPresets, kAudioUnitScope_Global, 0, &mEQPresetsArray, &size);
    
    AURenderCallbackStruct callback;
    callback.inputProc = WriteToFileRenderCallback;
    callback.inputProcRefCon = (__bridge void * _Nullable)(self);
    if (AudioUnitSetProperty(ipodEffectUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Output, 0, &callback, sizeof(callback)) != noErr) {
        [self printErrorMessage:@"Attach write file render callback to effect unit output failed" withStatus:result];return;
    }
    
    
    printf("iPodEQ Factory Preset List:\n");
    UInt8 count = CFArrayGetCount(mEQPresetsArray);
    NSMutableArray *names = [NSMutableArray arrayWithCapacity:count];
    for (int i = 0; i < count; ++i) {
        AUPreset *aPreset = (AUPreset*)CFArrayGetValueAtIndex(mEQPresetsArray, i);
        [names addObject:(__bridge id _Nonnull)(aPreset->presetName)];
        CFShow(aPreset->presetName);
    }
    
    if (self.didGetEffectsBlock) {
        self.didGetEffectsBlock(names);
    }
}

static OSStatus WriteToFileRenderCallback (
                                       void                        *inRefCon,
                                       AudioUnitRenderActionFlags  *ioActionFlags,
                                       const AudioTimeStamp        *inTimeStamp,
                                       UInt32                      inBusNumber,
                                       UInt32                      inNumberFrames,
                                       AudioBufferList             *ioData
                                       )
{
    ConnectAUNodesManager *manager = (__bridge ConnectAUNodesManager *)inRefCon;
    ExtAudioFileWriteAsync(manager->outFileRef, inNumberFrames, ioData);
    
    return noErr;
    
}

- (void)connectNodes {
    result = AUGraphConnectNodeInput(processingGraph, mPlayerNode, 0, mixerNode, 0);
    if (result != noErr) {
        [self printErrorMessage:@"connect mPlayerNode out -> mixerNode in" withStatus:result];return;
    }
    
    result = AUGraphConnectNodeInput(processingGraph, ioNode, 1, mixerNode, 1);
    if (result != noErr) {
        [self printErrorMessage:@"connect ioNode mic -> mixerNode in" withStatus:result];return;
    }
    
    if(AUGraphConnectNodeInput(processingGraph, mixerNode, 0, ipodEffectNode, 0) != noErr) {
        [self printErrorMessage:@"connect mixer out -> effect in" withStatus:result];return;
    }
    
    result = AUGraphConnectNodeInput(processingGraph, ipodEffectNode, 0, ioNode, 0);
    if (result != noErr) {
        [self printErrorMessage:@"connect mixerNode out -> io Node out" withStatus:result];return;
    }
    
    //    result = AUGraphConnectNodeInput(processingGraph, mPlayerNode, 0, ioNode, 0);
    //    if (result != noErr) {
    //        [self printErrorMessage:@"AUGraphConnectNodeInput" withStatus:result];return;
    //    }
    
    //    result = AUGraphConnectNodeInput(processingGraph, ioNode, 1, ioNode, 0);
    //    if (result != noErr) {
    //        [self printErrorMessage:@"AUGraphConnectNodeInput" withStatus:result];return;
    //    }
    
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
    
    if (outFileRef) {
        ExtAudioFileDispose(outFileRef);
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


// Mixer Unit

- (void)setMixerUnitOutputVolumn:(Float32)value {
    if (AudioUnitSetParameter(mixerUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Output, 0, value, 0) != noErr) {
        [self printErrorMessage:@"setMixerUnitOutputVolumn failed" withStatus:result];return;
    }
}

// Mic Unit

- (void)setMicUnitVolumn:(Float32)value {
    if(AudioUnitSetParameter(mixerUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 1, value, 0) != noErr) {
        [self printErrorMessage:@"setMicUnitVolumn failed" withStatus:result];return;
    }
}

// Player unit

- (void)setPlayerUnitVolumn:(Float32)value {
    if(AudioUnitSetParameter(mixerUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 0, value, 0) != noErr) {
        [self printErrorMessage:@"setPlayerUnitVolumn failed" withStatus:result];return;
    }
}

// effect unit

- (void)setIpodUnitEffectAtIndex: (int)index {
    /*
     Disabled, Acoustic, Bass Booster, Bass Reducer, Classical, Dance, Deep
     Electronic, Flat, Hip-Hop, Jazz, Latin, Loudness, Lounge, Piano, Pop
     R&B, Rock, Small Speakers, Spoken Word, Treble Booster, Treble Reducer, Vocal Booster
     */
    AUPreset *preset = (AUPreset*)CFArrayGetValueAtIndex(mEQPresetsArray, index);
    
    // 注意这里是 sizeof(AUPreset)
    if(AudioUnitSetProperty(ipodEffectUnit, kAudioUnitProperty_PresentPreset, kAudioUnitScope_Global, 0, preset, sizeof(AUPreset)) != noErr) {
        [self printErrorMessage:[NSString stringWithFormat:@"set ipod EQ effect: %@ failed", preset->presetName] withStatus:result];return;
    }
}

// file output

- (void)createFileOutput {
    
    NSString *outURLString = [CommonUtil documentsPath:@"output.caf"];
    NSURL *outURL = [NSURL URLWithString:outURLString];
    AudioStreamBasicDescription asbd = [self effectOutputASBD];
    
    ExtAudioFileCreateWithURL((__bridge CFURLRef)outURL, kAudioFileCAFType, &asbd, NULL, kAudioFileFlags_EraseFile, &(outFileRef));
    
    ExtAudioFileSetProperty(outFileRef, kExtAudioFileProperty_ClientDataFormat, sizeof(asbd), &asbd);
    int codec = kAppleHardwareAudioCodecManufacturer;
    ExtAudioFileSetProperty(outFileRef, kExtAudioFileProperty_CodecManufacturer, sizeof(codec), &codec);
}

@end
