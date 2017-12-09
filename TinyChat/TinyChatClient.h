//
//  TinyChatClient.h
//  TinyChat
//
//  Created by Matthew Lintlop on 12/8/17.
//  Copyright © 2017 Matthew Lintlop. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <netinet/in.h>

@interface TinyChatClient : NSObject

- (BOOL)connectToChatServer;
- (void)disconnect;

- (BOOL)writeData:(NSData*)data length:(NSUInteger)length;
- (int)readData:(char*)buffer length:(NSUInteger)maxLength;

- (void)checkForDataFromChatServer;

@property (nonatomic) int sockfd;
@property (nonatomic) BOOL connected;

@end
