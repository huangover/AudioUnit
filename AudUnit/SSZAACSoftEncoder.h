//
//  SSZAACSoftEncoder.h
//  SSZAVSDK
//
//  Created by SihangHuang on 2019/9/12.
//  Copyright © 2019 XianhuanLin. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SSZAudioConfig;

@protocol SSZAACSoftEncoderDelegate <NSObject>

- (void)aacSoftEncoderDidEncodeData:(void *)data len:(int)len;

@end

@interface SSZAACSoftEncoder : NSObject

- (instancetype)initWithAudioConfig:(SSZAudioConfig *)config;
// Return number of bytes actually encoded
- (void)encode:(short *)ioData len:(int)len;
- (void)stop;

@property (nonatomic, weak) id<SSZAACSoftEncoderDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
