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
-(void)clientDidConnect;
@end

@interface TinyChatClient : NSOperation

- (Boolean)connectToChatServer;
- (void)disconnect;

- (BOOL)writeData:(NSData*)data;
- (int)readData:(char*)buffer length:(NSUInteger)maxLength;

- (void)checkForDataFromChatServer;

- (void)setNetworkActivityIndicatorVisible:(BOOL)visible;

- (void)suspend;
- (void)resume;

- (void)main;

@property (nonatomic) int sockfd;
@property (nonatomic) BOOL connected;
@property (nonatomic) BOOL suspended;
@property (nonatomic, weak) id<TinyChatClientDelegate> delegate;

@end
