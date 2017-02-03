//
//  ViewController.h
//  TestWebKit
//
//  Created by Peter Gusev on 11/9/16.
//  Copyright © 2016 Peter Gusev. All rights reserved.
//

#import <UIKit/UIKit.h>

extern NSString* const kServerReconnectNeeded;

@protocol SettingsViewControllerDelegate;
@protocol RTCPeerConnectionDelegate;
@protocol RTCEAGLVideoViewDelegate;

@interface ViewController : UIViewController
<SettingsViewControllerDelegate, RTCPeerConnectionDelegate,
RTCEAGLVideoViewDelegate, UIWebViewDelegate>

@property (nonatomic, readonly) NSString *currentURL;

@end

