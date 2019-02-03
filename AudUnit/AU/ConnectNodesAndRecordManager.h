//
//  MyAudioUnitManager.h
//  FFmpegDecoder
//
//  Created by sihang huang on 2018/12/30.
//  Copyright © 2018 xiaokai.zhan. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
typedef void (^DidGetEffectsBlock)(NSArray *);
@interface ConnectNodesAndRecordManager : NSObject
- (void)constructUnits;
- (void)start;
- (void)stop;

// Mixer unit
- (void)setMixerUnitOutputVolumn:(Float32)value;

// Mic Unit

- (void)setMicUnitVolumn:(Float32)value;

// Player unit

- (void)setPlayerUnitVolumn:(Float32)value;

// effect unit

@property (nonatomic, copy) DidGetEffectsBlock didGetEffectsBlock;
- (void)setIpodUnitEffectAtIndex: (int)index;

@end

NS_ASSUME_NONNULL_END
