//
//  TinyChatClient.m
//  TinyChat
//
//  Created by Matthew Lintlop on 12/8/17.
//  Copyright © 2017 Matthew Lintlop. All rights reserved.
//

#import "TinyChatClient.h"
#import <sys/ioctl.h>
#import <sys/socket.h>
#import <stdio.h>
#import <stdlib.h>
#import <netdb.h>
#import <netinet/in.h>
#import <string.h>
#import <UIKit/UIKit.h>

@implementation TinyChatClient

- (instancetype)init {
    self = [super init];
    if (self) {
        self.connected = NO;
        self.suspended = YES;
    }
    return self;
}

- (void)connectToChatServer {
    struct hostent *server;
    struct sockaddr_in serv_addr;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    });
    
    // Create a socket point
    self.sockfd = socket(AF_INET, SOCK_STREAM, 0);
    if (self.sockfd < 0) {
        perror("ERROR opening socket");
    }
    server = gethostbyname("52.91.109.76");
    if (server == NULL) {
        fprintf(stderr, "ERROR, no such host: %s\n", "52.91.109.76");
    }
    printf("Resolved Host: %s\n", server->h_name);
    
    bzero((char*) &serv_addr, sizeof(serv_addr));
    serv_addr.sin_family = AF_INET;
    bcopy(server->h_addr_list[0], &serv_addr.sin_addr.s_addr, server->h_length);
    serv_addr.sin_port = htons(1234);
    
    // Now connect to the Chat Server using TCP
    if (connect(self.sockfd, (struct sockaddr*)&serv_addr, sizeof(serv_addr)) < 0) {
        NSLog(@"ERROR connecting");
        self.connected = NO;
    }
    else {
        self.connected = YES;
        [self.delegate clientDidConnect];
        NSLog(@"Connected to the chat server");
    }
      
    dispatch_async(dispatch_get_main_queue(), ^{
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    });
}

- (void)disconnect {
    if (self.connected) {
        if (self.sockfd != 0) {
            close(self.sockfd);
            self.sockfd = 0;
            NSLog(@"Disconnected from the chat server");
       }
        self.connected = NO;
    }
}

- (BOOL)writeData:(NSData*)data {
    if (!self.connected) {
        return NO;
    }
    
    NSLog(@"Write Data Current Thread: %X", [NSThread currentThread]);
    
    NSUInteger bytesRemaining = data.length;
    
    // Send the message to the TCP server.
    ssize_t n;
    do {
        n = write(self.sockfd, data.bytes, bytesRemaining);
        if (n > 0) {
            bytesRemaining -= n;
        }
    } while ((n > 0) && (bytesRemaining > 0));
    
    if (n < 0) {
        perror("ERROR writing to socket");
        return NO;
    }
    else {
        ssize_t n = write(self.sockfd, "\n", 1);
        return n > 0;
    }
}

- (int)readData:(char*)buffer length:(NSUInteger)maxLength {
    if (!self.connected) {
        return 0;
    }
    [self setNetworkIndicatorVisible:YES];

    bzero(buffer, 256);
    ssize_t bytesRead = read(self.sockfd, buffer, 255);
    if (bytesRead < 0) {
        perror("ERROR reading from socket");
    }
    [self setNetworkIndicatorVisible:NO];

    return (int)bytesRead;
}

- (void)checkForDataFromChatServer {
    if (!self.connected) {
        return;
    }
    int bytes_available;
    ioctl(self.sockfd,FIONREAD,&bytes_available);

    if (bytes_available > 0) {
        UInt8 buffer[bytes_available+1];
        UInt8* bufferValues = buffer;
        
        [self setNetworkIndicatorVisible:true];
        
        ssize_t n = read(self.sockfd, buffer, bytes_available);
        if (n > 0) {
            if ([[NSThread currentThread] isMainThread]) {
                [self.delegate processDataFromChatServer:buffer length:(int)n];
                [self setNetworkIndicatorVisible:false];
            }
            else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate processDataFromChatServer:bufferValues length:(int)n];
                    [self setNetworkIndicatorVisible:false];
               });
            }
        }
        else {
            [self setNetworkIndicatorVisible:false];
        }
    }
 }

- (void)suspend {
    if (!self.suspended) {
        self.suspended = TRUE;
    }
}

- (void)resume {
    if (self.suspended) {
        self.suspended = NO;
    }
}

- (void)setNetworkIndicatorVisible:(BOOL)visible {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (visible) {
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
        }
        else {
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
        }
   });
}

#pragma mark - NSOperation

- (void)main {
    NSLog(@"Tiny Chat Client Current Thread: %X", [NSThread currentThread]);

    [self connectToChatServer];
 
    while (!self.isCancelled) {
        if (!self.suspended) {
            [self checkForDataFromChatServer];
        }
        [NSThread sleepForTimeInterval:0.025];
    }
}

@end
