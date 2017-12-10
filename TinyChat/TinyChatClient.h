//
//  TinyChatClient.h
//  TinyChat
//
//  Created by Matthew Lintlop on 12/8/17.
//  Copyright © 2017 Matthew Lintlop. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <netinet/in.h>

@protocol TinyChatClientDelegate
-(void)processDataFromChatServer:(UInt8*)buffer length:(int)length;
@end

@interface TinyChatClient : NSObject

- (void)connectToChatServer;
- (void)disconnect;

- (BOOL)writeData:(NSData*)data length:(NSUInteger)length;
- (int)readData:(char*)buffer length:(NSUInteger)maxLength;

- (void)checkForDataFromChatServer;

- (void)suspend;
- (void)resume;

@property (nonatomic) int sockfd;
@property (nonatomic) BOOL connected;
@property (nonatomic, strong) NSTimer *readDataTimer;
@property (nonatomic, weak) id<TinyChatClientDelegate> delegate;

@end
