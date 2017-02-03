//
//  SettingsViewController.h
//  TestWebKit
//
//  Created by Peter Gusev on 12/7/16.
//  Copyright © 2016 Peter Gusev. All rights reserved.
//

#import <UIKit/UIKit.h>

extern NSString* const kServerAddressKey;
extern NSString* const kWebpageUrlKey;

@protocol SettingsViewControllerDelegate;

@interface SettingsViewController : UIViewController

@property (nonatomic, weak) id<SettingsViewControllerDelegate> delegate;

-(void)connect:(NSString*)serverAddress;

@end

@protocol SettingsViewControllerDelegate <NSObject>

-(void)onDidSetUrl:(NSURL*)urlAddress;
-(void)onDidChooseTestPage;

@end
