//
//  WebrtcSignallingController.h
//  TestWebKit
//
//  Created by Peter Gusev on 12/7/16.
//  Copyright © 2016 Peter Gusev. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^ConnectCallback)(NSError*);

extern NSString* const kWebrtcControllerErrorMessageKey;
extern NSString* const kWebrtcControllerGotIdNotificaiton;
extern NSString* const kWebrtcControllerIdKey;
extern NSString* const kWebrtcControllerProducerDisconnectedNotification;
extern NSString* const kWebrtcControllerProducerConnectedNotificaiton;
extern NSString* const kWebrtcControllerIceCandidatesNotification;
extern NSString* const kWebrtcControllerIceCandidatesKey;
extern NSString* const kWebrtcControllerGotOfferNotification;
extern NSString* const kWebrtcControllerOfferKey;
extern NSString* const kWebrtcControllerGotRecordsListNotification;
extern NSString* const kWebrtcControllerRecordsListKey;

@interface WebrtcSignallingController : NSObject

+(WebrtcSignallingController*)sharedInstance;

@property (nonatomic, readonly) NSString *serverAddress;
@property (nonatomic, readonly) NSString *address;
@property (nonatomic, readonly) NSUInteger port;


-(void)connectTo:(NSString*)ipAddress
          atPort:(NSUInteger)portNum
    withCallback:(ConnectCallback)onResult;

-(void)sendSdpAnswer:(NSDictionary*)sdp;
-(void)sendIceCandidate:(NSDictionary*)ice;
-(void)requestRecordsList;

@end
