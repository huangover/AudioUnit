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

@protocol RenderAUDataManagerDelegate <NSObject>

- (void)fillBuffer:(short *)buffer withSize:(int)size;
- (int)numOfChannels;

@end

@interface RenderAUDataManager : NSObject

@property (nonatomic, weak) id<RenderAUDataManagerDelegate> delegate;

- (void)constructUnits;
- (void)start;
- (void)stop;

@property (nonatomic, copy) DidGetEffectsBlock didGetEffectsBlock;

@end

NS_ASSUME_NONNULL_END
