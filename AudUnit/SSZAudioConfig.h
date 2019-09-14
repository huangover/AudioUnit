//
//  SSZAudioConfig.h
//  AudUnit
//
//  Created by Sihang Huang on 9/14/19.
//  Copyright © 2019 sihang huang. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SSZAudioConfig: NSObject

@property (nonatomic, assign) NSInteger bitRate;
@property (nonatomic, assign) int sampleRate;
@property (nonatomic, assign) int channel;

@end

NS_ASSUME_NONNULL_END
