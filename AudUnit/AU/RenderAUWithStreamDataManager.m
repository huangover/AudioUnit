//
//  MyAudioUnitManagerCallback.m
//  AudUnit
//
//  Created by Sihang Huang on 1/15/19.
//  Copyright © 2019 sihang huang. All rights reserved.
//
//  这个类的代码只有IO unit，由input callback驱动渲染音乐。callback的填充方式有两种：
// 1. 由NSStream来读数据并填充到buffer中
// 2. 由delegate回调获取一块一块的代码

#import "RenderAUWithStreamDataManager.h"
#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVFoundation.h>

@interface RenderAUWithStreamDataManager()
@property (nonatomic, assign) double mySampleRate;
@property (nonatomic, strong) NSInputStream *stream;
@end

@implementation RenderAUWithStreamDataManager
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
//    [self setUpPlayerUnit];
//    [self readPCMProperties];
//    [self setUpMixerUnit];
//    [self setUpEffectUnit];
//    [self connectNodes];
    [self initGraph];
//    [self setUpPlayerParamsAfterGraphInit];//只有对Graph进行Initialize之后才可以设置AudioPlayer的参数
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

- (void)setUpGraph {
    result = NewAUGraph(&processingGraph);
    if (result != noErr) {
        [self printErrorMessage:@"NewAUGraph" withStatus:result];
        return;
    }
    
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
}

- (void)setUpIOUnit {
    
    result = AUGraphNodeInfo(processingGraph, ioNode, NULL, &ioUnit);
    if (result != noErr) {
        [self printErrorMessage:@"AUGraphNodeInfo+ioNode" withStatus:result];return;
    }
    
//    // 打开mic
//    int enableIO = 1;
//    result = AudioUnitSetProperty(ioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &enableIO, sizeof(enableIO));
//    if (result != noErr) {
//        [self printErrorMessage:@"AudioUnitSetProperty+enableIO+micUnit" withStatus:result];return;
//    }
//
//    AudioStreamBasicDescription asbd = {0};
//    int channels = 2;
//    UInt32 bytesPerSample = sizeof(Float32);
//    asbd.mSampleRate = self.mySampleRate;
//    // Yes, I know you probably want floating point samples, but the iPhone isn't going
//    // to give you floating point data. You'll need to make the conversion by hand from
//    // linear PCM <-> float.
//    asbd.mFormatID = kAudioFormatLinearPCM;
//    asbd.mFormatFlags = kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved;
//    asbd.mChannelsPerFrame = channels; // 1 for mono. 2 for stereo.
//
//    asbd.mFramesPerPacket = 1;
//    asbd.mBytesPerFrame = bytesPerSample;
//    asbd.mBytesPerPacket = bytesPerSample;
//    asbd.mBitsPerChannel = 8 * bytesPerSample;
//
//    result = AudioUnitSetProperty(ioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &asbd, sizeof(asbd));
//    if (result != noErr) {
//        [self printErrorMessage:@"AudioUnitSetProperty+streamFormat+micUnit" withStatus:result];return;
//    }
    
    
    // 如果是interleaved: mChannelsPerFrame可以是1也可以是2，但是 mBytesPerFrame = mBytesPerPacket = bytesPerSample * mChannelsPerFrame
    // 如果是non-interleaved，mChannelsPerFrame 1和2都行，但是 mBytesPerFrame = mBytesPerPacket必须是bytesPerSample
    
    AudioStreamBasicDescription asbd = {0};
    UInt32 bytesPerSample = 2; // sizeof(Float32); 很重要！因为输入的pcm文件的位深就是2，不然播放时会有啸声
    asbd.mSampleRate = self.mySampleRate;
    asbd.mFormatID = kAudioFormatLinearPCM;
    asbd.mFramesPerPacket = 1;
    asbd.mBitsPerChannel = 8 * bytesPerSample;
    
    // 版本1：interleaved
    // 播放mono音乐文件，mChannelsPerFrame必须设置为1，否则播放不对
    // 播放stereo音乐文件，mChannelsPerFrame必须设置为2，否则播放不对
    
    if (true) {
        
        /*
         asbd.mChannelsPerFrame = 2时:
         (AudioBufferList) $0 = {
            mNumberBuffers = 1
            mBuffers = {
                [0] = (mNumberChannels = 2, mDataByteSize = 2048, mData = 0x00007f844e84be00)
            }
         }
         
         asbd.mChannelsPerFrame = 1时:
         (AudioBufferList) $0 = {
            mNumberBuffers = 1
            mBuffers = {
                [0] = (mNumberChannels = 1, mDataByteSize = 1024, mData =   0x00007fb77283a800)
            }
         }
         */
        
        asbd.mFormatFlags = kAudioFormatFlagIsSignedInteger;
        
        if ([self.delegate respondsToSelector:@selector(numOfChannels)]) {
            asbd.mChannelsPerFrame = [self.delegate respondsToSelector:@selector(numOfChannels)];
        } else {
            asbd.mChannelsPerFrame = 2; // 1 for mono. 2 for stereo.
        }
        
        asbd.mBytesPerFrame = asbd.mChannelsPerFrame * bytesPerSample;
        asbd.mBytesPerPacket = asbd.mChannelsPerFrame * bytesPerSample;
    }
    
    if (false) {
        /*
             (AudioBufferList) $0 = {
                  mNumberBuffers = 1
                  mBuffers = {
                      [0] = (mNumberChannels = 1, mDataByteSize = 1024, mData = 0x00007f963f021000)
                  }
             }
         */
        
        // 版本2: non-interleaved + mChannelsPerFrame = 1
        asbd.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsNonInterleaved;
        asbd.mChannelsPerFrame = 1;
        asbd.mBytesPerFrame =  bytesPerSample;
        asbd.mBytesPerPacket = bytesPerSample;
    }

    if (false) {
        /*
            (AudioBufferList) $0 = {
                mNumberBuffers = 2
                mBuffers = {
                    [0] = (mNumberChannels = 1, mDataByteSize = 1024, mData = 0x00007fa181048000)
                }
            }
         */
        
        // 版本3: non-interleaved + mChannelsPerFrame = 2
        asbd.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsNonInterleaved;
        asbd.mChannelsPerFrame = 2; // 此时必须把mBuffers[0]（左耳）和mBuffers[1]（右耳）都填上数据
        asbd.mBytesPerFrame =  bytesPerSample;
        asbd.mBytesPerPacket = bytesPerSample;
    }
    
    result = AudioUnitSetProperty(ioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &asbd, sizeof(asbd));
    if (result != noErr) {
        [self printErrorMessage:@"AudioUnitSetProperty+streamFormat+speakerUnit" withStatus:result];return;
    }
    
//    [self createStreamFromPCMFile];
    
//    if (self.stream) {
        // 扬声器的inputScope设置callback，给扬声器提供数据
        AURenderCallbackStruct callback;
        callback.inputProc = &SpeakerRenderCallback;
        callback.inputProcRefCon = (__bridge void *)self;
        
        if(AUGraphSetNodeInputCallback(processingGraph, ioNode, 0, &callback) != noErr ) {
            [self printErrorMessage:@"AudioUnitSetProperty+ speaker callback + failed" withStatus:result];return;
        }
        
        Boolean graphUpdated;
        if(AUGraphUpdate (processingGraph, &graphUpdated) != noErr) {
            [self printErrorMessage:@"AUGraphUpdate+ add speaker callback + failed" withStatus:result];return;
        }
//    }
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
    /*
    struct AudioBuffer
    {
     //The number of interleaved channels in the buffer.
     // interleaved: 由asbd的mChannelsPerFrame决定
     // non-interleaved: 1
        UInt32              mNumberChannels;
     
     // The number of bytes in the buffer pointed at by mData. 当mChannelsPerFrame为2时，mDataByteSize是mChannelsPerFrame为1时的2倍。
        UInt32              mDataByteSize;
     
         //A pointer to the buffer of audio data.
        void* __nullable    mData;
    };
    
    struct AudioBufferList
    {
     // interleaved(mNumberBuffers = 1)
     // non-interleaved(mNumberBuffers = asbd.mChannelsPerFrame)决定。
        UInt32      mNumberBuffers;
     
     // interleaved(mNumberBuffers = 1), mBuffers.count = 1;
     // non-interleaved(mNumberBuffers = asbd.mChannelsPerFrame), mBuffers.count = asbd.mChannelsPerFrame
        AudioBuffer mBuffers[1];
     }
     */
    
    
    //每个音频文件都是interleaved的，按照LRLRLR的形式存储左右声道数据。如果为单声道，那么L均为0或者R均为0；如果是stereo，L和R都有值。
    //asbd里面的non-interleaved，是强行给分开，分成左耳机听到的声音和右耳机听到的声音
    
    if (false) {
        
        // 对应播放abc.pcm(mono, pcm文件其实是interleaved的)，asbd设置为non-interleaved.
        
        // 为什么取2*mDataByteSize出来？而306，307行又要除以2？
        // 自己想的答案：“PCM 格式就是把每个声道的数据按 interleaved 的方式存储，也就是你说的 LRLRLR 这样”。因为abc.pcm是单声道的，所以R都是0->需要读2倍的长度->所以赋值的时候需要除以2
        // 假设ioData->mBuffers[1] 长度为5需要填充. 取出10位长PCM数据为1010101010（10位长），才能把5个1填满mBuffers，填的时候1的位置，都在i/2
        
        RenderAUWithStreamDataManager *manager = (__bridge RenderAUWithStreamDataManager *)inRefCon;
    
        uint8_t *array = malloc(ioData->mBuffers[0].mDataByteSize * 2);
        int bytesRead = [manager.stream read:array maxLength:ioData->mBuffers[0].mDataByteSize * 2];
    
        for (int i =0; i< bytesRead;i++) {
            ((Byte *)ioData->mBuffers[0].mData)[i/2] = array[i];
            ((Byte *)ioData->mBuffers[1].mData)[i/2] = array[i];
        }
    }
    
    if (false) {
        RenderAUWithStreamDataManager *manager = (__bridge RenderAUWithStreamDataManager *)inRefCon;
        int bytesRead = [manager.stream read:ioData->mBuffers[0].mData maxLength:ioData->mBuffers[0].mDataByteSize];
        ioData->mBuffers[0].mDataByteSize = bytesRead;
    }
    
    if (true) {
        RenderAUWithStreamDataManager *manager = (__bridge RenderAUWithStreamDataManager *)inRefCon;
        
        if ([manager.delegate respondsToSelector:@selector(fillBuffer:withSize:)]) {
            [manager.delegate fillBuffer:ioData->mBuffers[0].mData withSize:ioData->mBuffers[0].mDataByteSize];
            
        }
        
        return noErr;
    }
}

- (void)createStreamFromPCMFile {
    //abc.pcm mono
    //test.pcm stereo
    NSString *path = [[NSBundle mainBundle] pathForResource:@"test" ofType:@"pcm"];
    self.stream = [NSInputStream inputStreamWithFileAtPath:path];
    
    if (!self.stream) {
        [self printErrorMessage:@"NSInputStream + test.pcm failed" withStatus:result];return;
    } else {
        [self.stream open];
    }
}

- (void)readPCMProperties {
    NSURL *fileURL = [NSURL URLWithString:[[NSBundle mainBundle] pathForResource:@"test" ofType:@"pcm"]];
    CFURLRef inFileRef = (__bridge CFURLRef)fileURL;

    AudioFileID outAudioFile;
    if (AudioFileOpenURL(inFileRef, kAudioFileReadPermission, 0, &outAudioFile) != noErr) {
        [self printErrorMessage:@"AudioFileOpenURL+test.pcm failed" withStatus:result];return;
    }
    
    /*
     Float64             mSampleRate;
     UInt32              mBytesPerPacket;
     UInt32              mFramesPerPacket;
     UInt32              mBytesPerFrame;
     UInt32              mChannelsPerFrame;
     UInt32              mBitsPerChannel;
     */
    AudioStreamBasicDescription asbd;
    UInt32 size = sizeof(asbd);
    if (AudioFileGetProperty(outAudioFile, kAudioFilePropertyDataFormat, &size, &asbd) != noErr) {
        [self printErrorMessage:@"AudioFileGetProperty + asbd + test.pcm failed" withStatus:result];return;
    }
    
    
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
    if(AudioUnitSetProperty(ipodEffectUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &asbd, sizeof(asbd)) != noErr) {
        [self printErrorMessage:@"set stream format + effect Unit" withStatus:result];return;
    }
    
    UInt32 size = sizeof(mEQPresetsArray);
    AudioUnitGetProperty(ipodEffectUnit, kAudioUnitProperty_FactoryPresets, kAudioUnitScope_Global, 0, &mEQPresetsArray, &size);
    
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

- (void)connectNodes {
//    result = AUGraphConnectNodeInput(processingGraph, mPlayerNode, 0, mixerNode, 0);
//    if (result != noErr) {
//        [self printErrorMessage:@"connect mPlayerNode out -> mixerNode in" withStatus:result];return;
//    }
//
//    result = AUGraphConnectNodeInput(processingGraph, ioNode, 1, mixerNode, 1);
//    if (result != noErr) {
//        [self printErrorMessage:@"connect ioNode mic -> mixerNode in" withStatus:result];return;
//    }
//
//    if(AUGraphConnectNodeInput(processingGraph, mixerNode, 0, ipodEffectNode, 0) != noErr) {
//        [self printErrorMessage:@"connect mixer out -> effect in" withStatus:result];return;
//    }
//
//    result = AUGraphConnectNodeInput(processingGraph, ipodEffectNode, 0, ioNode, 0);
//    if (result != noErr) {
//        [self printErrorMessage:@"connect mixerNode out -> io Node out" withStatus:result];return;
//    }
    
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

@end
