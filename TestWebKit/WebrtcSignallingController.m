//
//  WebrtcSignallingController.m
//  TestWebKit
//
//  Created by Peter Gusev on 12/7/16.
//  Copyright © 2016 Peter Gusev. All rights reserved.
//

#import "WebrtcSignallingController.h"

#include <arpa/inet.h>
@import SocketIO;

NSString* const kWebrtcControllerErrorDomain = @"kWebrtcControllerErrorDomain";
NSString* const kWebrtcControllerErrorMessageKey = @"message";
NSString* const kWebrtcControllerGotIdNotificaiton = @"kWebrtcControllerGotIdNotificaiton";
NSString* const kWebrtcControllerIdKey = @"consumer-key";
NSString* const kWebrtcControllerProducerDisconnectedNotification = @"kWebrtcControllerProducerDisconnectedNotification";
NSString* const kWebrtcControllerProducerConnectedNotificaiton = @"kWebrtcControllerProducerConnectedNotificaiton";
NSString* const kWebrtcControllerIceCandidatesNotification = @"kWebrtcControllerIceCandidatesNotification";
NSString* const kWebrtcControllerIceCandidatesKey = @"candidates";
NSString* const kWebrtcControllerGotOfferNotification = @"kWebrtcControllerGotOfferNotification";
NSString* const kWebrtcControllerOfferKey = @"offer";


@implementation NSString (IPValidation)

- (BOOL)isValidIPAddress
{
    const char *utf8 = [self UTF8String];
    int success;
    
    struct in_addr dst;
    success = inet_pton(AF_INET, utf8, &dst);
    if (success != 1) {
        struct in6_addr dst6;
        success = inet_pton(AF_INET6, utf8, &dst6);
    }
    
    return success == 1;
}

@end

//******************************************************************************
@interface WebrtcSignallingController()

@property (nonatomic) SocketIOClient *socket;

@end

@implementation WebrtcSignallingController

+(WebrtcSignallingController *)sharedInstance
{
    static WebrtcSignallingController *ctrl;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        ctrl = [[WebrtcSignallingController alloc] init];
    });
    
    return ctrl;
}

-(instancetype)init
{
    if ((self = [super init]))
    {
        // nothing here yet
    }
    
    return self;
}


-(void)connectTo:(NSString *)ipAddress
          atPort:(NSUInteger)portNum
    withCallback:(ConnectCallback)onResult
{
    if ([ipAddress isValidIPAddress])
    {
        NSURL *serverURL = [NSURL URLWithString: [NSString stringWithFormat:@"http://%@:%lu", ipAddress, (unsigned long)portNum]];
        self.socket = [[SocketIOClient alloc] initWithSocketURL:serverURL config:nil];
        
        [self.socket on:@"connect" callback:^(NSArray* data, SocketAckEmitter* ack) {
            NSLog(@"socket connected");
            onResult(nil);
            [self setupSocketProtocol];
            [self.socket emit:@"id" with:@[@"consumer"]];
        }];
        
        [self.socket on:@"disconnect" callback:^(NSArray* data, SocketAckEmitter* ack) {
            NSLog(@"socket disconnected");
            onResult([NSError errorWithDomain:kWebrtcControllerErrorDomain
                                         code:-101
                                     userInfo:@{kWebrtcControllerErrorMessageKey:@"unknown"}]);;
        }];
        
        [self.socket connect];
        NSLog(@"connecting to %@...", serverURL);
    }
    else
        onResult([NSError errorWithDomain:kWebrtcControllerErrorDomain
                                     code:-100
                                 userInfo:@{kWebrtcControllerErrorMessageKey:@"Invalid IP address"}]);
}

-(void)sendSdpAnswer:(NSDictionary*)sdp
{
    [self.socket emit:@"answer" with:@[sdp]];
}

-(void)sendIceCandidate:(NSDictionary*)ice
{
    [self.socket emit:@"ice" with:@[ice]];
}

#pragma mark - private
-(void)setupSocketProtocol
{
    [self.socket on:@"id" callback:^(NSArray * data, SocketAckEmitter * ack) {
        NSLog(@"got id: %@", data.firstObject);
        [[NSNotificationCenter defaultCenter] postNotificationName:kWebrtcControllerGotIdNotificaiton
                                                            object:self
                                                          userInfo:@{kWebrtcControllerIdKey:data.firstObject}];
    }];
    
    [self.socket on:@"producer dead" callback:^(NSArray * data, SocketAckEmitter * ack) {
        NSLog(@"producer dead");
        [[NSNotificationCenter defaultCenter] postNotificationName:kWebrtcControllerProducerDisconnectedNotification
                                                            object:self
                                                          userInfo:nil];
    }];
    
    [self.socket on:@"producer alive" callback:^(NSArray * data, SocketAckEmitter * ack) {
        NSLog(@"producer alive");
        [[NSNotificationCenter defaultCenter] postNotificationName:kWebrtcControllerProducerConnectedNotificaiton
                                                            object:self
                                                          userInfo:nil];
    }];
    
    [self.socket on:@"ice" callback:^(NSArray * data, SocketAckEmitter * ack) {
        NSLog(@"got ice candidates");
        [[NSNotificationCenter defaultCenter] postNotificationName:kWebrtcControllerIceCandidatesNotification
                                                            object:self
                                                          userInfo:@{kWebrtcControllerIceCandidatesKey:data}];
    }];
    
    [self.socket on:@"offer" callback:^(NSArray * data, SocketAckEmitter * ack) {
        NSLog(@"got offer");
        [[NSNotificationCenter defaultCenter] postNotificationName:kWebrtcControllerGotOfferNotification
                                                            object:self
                                                          userInfo:@{kWebrtcControllerOfferKey:data.firstObject[@"sdp"]}];
    }];
}

@end
