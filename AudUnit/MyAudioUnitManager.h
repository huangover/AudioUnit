//
//  MyAudioUnitManager.h
//  FFmpegDecoder
//
//  Created by sihang huang on 2018/12/30.
//  Copyright © 2018 xiaokai.zhan. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MyAudioUnitManager : NSObject
- (void)constructUnits;
- (void)start;
- (void)stop;
@end

NS_ASSUME_NONNULL_END
