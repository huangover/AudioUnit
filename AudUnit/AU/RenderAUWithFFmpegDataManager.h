//
//  MyAudioUnitManagerCallback.h
//  AudUnit
//
//  Created by Sihang Huang on 1/15/19.
//  Copyright © 2019 sihang huang. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^DidGetEffectsBlock)(NSArray *);

@class RenderAUWithFFmpegDataManager;

@protocol RenderAUWithFFmpegDataManagerDelegate <NSObject>
//给sample code的decoder
- (NSInteger)renderAUWithFFmpegDataManager:(RenderAUWithFFmpegDataManager *)manager fillAudioData:(SInt16*) sampleBuffer numFrames:(NSInteger)frameNum numChannels:(NSInteger)channels;
// 给自己的decoder
- (void)renderAUWithFFmpegDataManager:(RenderAUWithFFmpegDataManager *)manager fillBuffer:(short *)buffer withSize:(int)size ;
- (int)numOfChannelsForManager:(RenderAUWithFFmpegDataManager *)manager;
- (double)sampleRateForManager:(RenderAUWithFFmpegDataManager *)manager;

@end

@interface RenderAUWithFFmpegDataManager : NSObject

@property (nonatomic, weak) id<RenderAUWithFFmpegDataManagerDelegate> delegate;

- (void)constructUnits;
- (void)start;
- (void)stop;

@property (nonatomic, copy) DidGetEffectsBlock didGetEffectsBlock;

@end

NS_ASSUME_NONNULL_END
