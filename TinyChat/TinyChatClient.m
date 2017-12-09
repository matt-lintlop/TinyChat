//
//  TinyChatClient.m
//  TinyChat
//
//  Created by Matthew Lintlop on 12/8/17.
//  Copyright © 2017 Matthew Lintlop. All rights reserved.
//

#import "TinyChatClient.h"
#import <sys/socket.h>
#import <stdio.h>
#import <stdlib.h>
#import <netdb.h>
#import <netinet/in.h>
#import <string.h>

@implementation TinyChatClient

- (instancetype)init {
    self = [super init];
    if (self) {
        self.connected = NO;
    }
    return self;
}

- (BOOL)connectToChatServer {
    struct hostent *server;
    struct sockaddr_in serv_addr;
    
    // Create a socket point
    self.sockfd = socket(AF_INET, SOCK_STREAM, 0);
    if (self.sockfd < 0) {
        perror("ERROR opening socket");
        exit(1);
    }
    server = gethostbyname("52.91.109.76");
    if (server == NULL) {
        fprintf(stderr, "ERROR, no such host: %s\n", "52.91.109.76");
        exit(0);
    }
    printf("Resolved Host: %s\n", server->h_name);
    
    bzero((char*) &serv_addr, sizeof(serv_addr));
    serv_addr.sin_family = AF_INET;
    bcopy((char*)server->h_addr_list[0], (char*)&serv_addr.sin_addr.s_addr, server->h_length);
    serv_addr.sin_port = htons(1234);
    
    // Now connect to the TCP Server
    if (connect(self.sockfd, (struct sockaddr*)&serv_addr, sizeof(serv_addr)) < 0) {
        NSLog(@"ERROR connecting");
        self.connected = NO;
        return NO;
    }
    else {
        self.connected = YES;
        NSLog(@"Connected to the chat server");
        return YES;
    }
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

- (BOOL)writeData:(NSData*)data length:(NSUInteger)length {
    if (!self.connected) {
        return NO;
    }
    NSUInteger bytesRemaining = length;
    
    // Send the message to the TCP server.
    ssize_t n;
    do {
        n = write(self.sockfd, data.bytes, length);
        if (n > 0) {
            bytesRemaining -= n;
        }
    } while ((n > 0) && (bytesRemaining > 0));
    
    if (n < 0) {
        perror("ERROR writing to socket");
        return NO;
    }
    else {
        NSLog(@"Write: %ld Bytes: %s", n, data.bytes);
        ssize_t n = write(self.sockfd, "\n", 1);
        return n > 0;
    }
}

- (int)readData:(char*)buffer length:(NSUInteger)maxLength {
    if (!self.connected) {
        return 0;
    }
    bzero(buffer, 256);
    ssize_t bytesRead = read(self.sockfd, buffer, 255);
    if (bytesRead < 0) {
        perror("ERROR reading from socket");
    }
    return (int)bytesRead;

}

@end