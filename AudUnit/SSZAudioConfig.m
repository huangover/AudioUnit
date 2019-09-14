//
//  SSZAudioConfig.m
//  AudUnit
//
//  Created by Sihang Huang on 9/14/19.
//  Copyright © 2019 sihang huang. All rights reserved.
//

#import "SSZAudioConfig.h"

@implementation SSZAudioConfig

- (instancetype)init {
    self = [super init];
    if (self) {
        self.sampleRate = 44100;
        self.bitRate = 100000;
        self.channel = 2;
    }
    
    return self;
}

@end
