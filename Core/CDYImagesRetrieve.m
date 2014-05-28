/*
 * Copyright 2014 Coodly OÜ
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <CDYImagesRetrieve/CDYImageAsk.h>
#import "CDYImagesRetrieve.h"
#import "CDYImagesRetrieveConstants.h"
#import "AFHTTPRequestOperationManager.h"

@interface CDYImagesRetrieve ()

@property (nonatomic, copy) NSString *cachePath;
@property (nonatomic, strong) NSMutableArray *asksQueue;
@property (nonatomic, strong) CDYImageAsk *processedAsk;

@end

@implementation CDYImagesRetrieve {
    dispatch_queue_t __retrieveQueue;
}

- (id)initWithName:(NSString *)name {
    self = [super init];

    if (self) {
        _asksQueue = [NSMutableArray array];
        NSURL *cachesFolder = [[[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] lastObject];
        NSString *cachesPath = [cachesFolder path];
        cachesPath = [cachesPath stringByAppendingPathComponent:name];
        cachesPath = [cachesPath stringByAppendingPathComponent:@"images"];
        [[NSFileManager defaultManager] createDirectoryAtPath:cachesPath withIntermediateDirectories:YES attributes:nil error:nil];
        _cachePath = cachesPath;
    }

    return self;
}

- (id)init {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"You must use [%@ %@] instead",
                                                                     NSStringFromClass([self class]),
                                                                     NSStringFromSelector(@selector(sharedInstance))]
                                 userInfo:nil];
    return nil;
}

- (BOOL)hasImageForAsk:(CDYImageAsk *)ask {
    NSString *cachedFilePath = [self cachePathForAsk:ask];
    return [[NSFileManager defaultManager] fileExistsAtPath:cachedFilePath];
}

- (UIImage *)imageForAsk:(CDYImageAsk *)ask {
    NSString *cachedFilePath = [self cachePathForAsk:ask];
    NSData *data = [NSData dataWithContentsOfFile:cachedFilePath];
    return [[UIImage alloc] initWithData:data];
}

- (void)retrieveImageForAsk:(CDYImageAsk *)ask completion:(CDYImageRetrieveBlock)completion {
    dispatch_async([self retrieveQueue], ^{
        if ([self.processedAsk isEqual:ask]) {
            CDYIRLog(@"Ask already processed");
            return;
        }

        [self.asksQueue removeObject:ask];
        [self.asksQueue insertObject:ask atIndex:0];
        [ask setCompletion:completion];
        [self processNextAsk];
    });
}

- (void)processNextAsk {
    dispatch_async([self retrieveQueue], ^{
        if (self.processedAsk) {
            CDYIRLog(@"Ask already in progress");
            return;
        }

        CDYImageAsk *ask = [self.asksQueue firstObject];
        if (!ask) {
            CDYIRLog(@"Asks queue empty");
            return;
        }

        [self setProcessedAsk:ask];
        [self.asksQueue removeObject:ask];

        AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
        [manager.operationQueue setMaxConcurrentOperationCount:1];
        [manager setResponseSerializer:[AFImageResponseSerializer serializer]];
        CDYIRLog(@"Pull image from %@", ask.imageURL);
        [manager GET:ask.imageURL.absoluteString parameters:@"" success:^(AFHTTPRequestOperation *operation, id responseObject) {
            dispatch_async([self retrieveQueue], ^{
                CDYIRLog(@"Success");
                ask.completion(ask, responseObject);
                [self setProcessedAsk:nil];
                [self processNextAsk];
            });
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            dispatch_async([self retrieveQueue], ^{
                CDYIRLog(@"Error:%@", error);
                [self setProcessedAsk:nil];
                [self processNextAsk];
            });
        }];
    });
}

- (NSString *)cachePathForAsk:(CDYImageAsk *)ask {
    NSString *cacheKey = [self cacheKeyForAsk:ask];
    return  [self.cachePath stringByAppendingPathComponent:cacheKey];
}

- (NSString *)cacheKeyForAsk:(CDYImageAsk *)ask {
    NSString *key = ask.imageURL.absoluteString;
    key = [key stringByAppendingString:NSStringFromCGSize(ask.resultSize)];
    key = [key stringByReplacingOccurrencesOfString:@" " withString:@"_"];
    key = [key stringByReplacingOccurrencesOfString:@":" withString:@""];
    key = [key stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    key = [key stringByReplacingOccurrencesOfString:@"?" withString:@"_"];
    key = [key stringByReplacingOccurrencesOfString:@"=" withString:@"_"];

    return key;
}

- (dispatch_queue_t)retrieveQueue {
    if (__retrieveQueue == NULL) {
        __retrieveQueue = dispatch_queue_create("com.coodly.dyimagesretrieve.queue", NULL);
    }

    return __retrieveQueue;
}

@end
