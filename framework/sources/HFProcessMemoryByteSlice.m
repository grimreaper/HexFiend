//
//  HFProcessMemoryByteSlice.m
//  HexFiend_2
//
//  Created by Peter Ammon on 8/23/09.
//  Copyright 2009 Apple Computer. All rights reserved.
//

#import "HFProcessMemoryByteSlice.h"
#import "HFPrivilegedHelperConnection.h"
#import "HFByteRangeAttributeArray.h"
#import "HFByteRangeAttribute.h"

@implementation HFProcessMemoryByteSlice

- (id)initWithPID:(pid_t)pid range:(HFRange)range {
    [super init];
    processIdentifier = pid;
    memoryRange = range;
    return self;
}

- (unsigned long long)length {
    return memoryRange.length;
}

- (HFPrivilegedHelperConnection *)connection {
    return [HFPrivilegedHelperConnection sharedConnection];
}

- (void)copyBytes:(unsigned char *)dst range:(HFRange)range {
    HFASSERT(HFMaxRange(range) <= memoryRange.length);
    NSError *error = nil;
    range.location = HFSum(range.location, memoryRange.location);
    [[self connection] readBytes:dst range:range process:processIdentifier error:&error];
}

- (HFByteSlice *)subsliceWithRange:(HFRange)range {
    HFASSERT(HFMaxRange(range) <= memoryRange.length);
    if (range.length == memoryRange.length) return self;
    HFRange newMemoryRange = HFRangeMake(HFSum(range.location, memoryRange.location), range.length);
    return [[[[self class] alloc] initWithPID:processIdentifier range:newMemoryRange] autorelease];
}

- (HFByteRangeAttributeArray *)attributesForBytesInRange:(HFRange)range {
    HFRange remainingRange = range;
    HFByteRangeAttributeArray *attributeArray = [[[HFByteRangeAttributeArray alloc] init] autorelease];
    while (remainingRange.length > 0) {
        NSError *error = nil;
        unsigned long long runLength = 0;
        VMRegionAttributes attributes = 0;
        BOOL success = [[self connection] getAttributes:&attributes length:&runLength offset:HFSum(remainingRange.location, memoryRange.location) process:processIdentifier error:&error];
        if (! success) {
            return nil;
        }
        HFRange attributeRange = HFRangeMake(remainingRange.location, runLength);
        if (attributes & VMRegionUnmapped) [attributeArray addAttribute:kHFAttributeUnmapped range:attributeRange];
        if (! (attributes & VMRegionReadable)) [attributeArray addAttribute:kHFAttributeUnreadable range:attributeRange];
        if (attributes & VMRegionWritable) [attributeArray addAttribute:kHFAttributeWritable range:attributeRange];
        if (attributes & VMRegionExecutable) [attributeArray addAttribute:kHFAttributeExecutable range:attributeRange];
        if (attributes & VMRegionShared) [attributeArray addAttribute:VMRegionShared range:attributeRange];
        
        remainingRange.location += runLength; //don't care about overflow here
        remainingRange.length -= MAX(runLength, remainingRange.length);
    }
    return attributeArray;
}

@end