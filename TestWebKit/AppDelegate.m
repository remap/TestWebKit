//
//  AppDelegate.m
//  TestWebKit
//
//  Created by Peter Gusev on 11/9/16.
//  Copyright © 2016 Peter Gusev. All rights reserved.
//

#import "AppDelegate.h"
#import "ViewController.h"
#import "SettingsViewController.h"
#import "WebrtcSignallingController.h"

NSString* const kEnableSettings = @"enableSettings";

@interface AppDelegate ()

@property (nonatomic) UISplitViewController *splitViewController;

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.splitViewController = (UISplitViewController*)self.window.rootViewController;
    self.splitViewController.preferredDisplayMode = UISplitViewControllerDisplayModePrimaryHidden;
    
    SettingsViewController *masterVC = [self.splitViewController.viewControllers.firstObject topViewController];
    ViewController *detailVC = self.splitViewController.viewControllers.lastObject;
    
    masterVC.delegate = detailVC;
    
    self.splitViewController.presentsWithGesture = [[NSUserDefaults standardUserDefaults] boolForKey:kEnableSettings];
    
    [self checkWebUrlChange: YES];
    [self checkSignalingServerChange: YES];
    
    return YES;
}


- (void)applicationWillResignActive:(UIApplication *)application {
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    
    [self checkSettingsPanelChange];
    [self checkWebUrlChange: NO];
    [self checkSignalingServerChange: NO];
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


#pragma mark - private
-(void)checkSettingsPanelChange
{
    BOOL enableSettings = [[NSUserDefaults standardUserDefaults] boolForKey:kEnableSettings];
    
    self.splitViewController.presentsWithGesture = enableSettings;
    
    if (!enableSettings)
        [self.splitViewController setPreferredDisplayMode: UISplitViewControllerDisplayModePrimaryHidden];
}

-(void)checkWebUrlChange:(BOOL)forceUpdate
{
    ViewController *detailVC = self.splitViewController.viewControllers.lastObject;
    NSString *webUrl = [[NSUserDefaults standardUserDefaults] objectForKey:kWebpageUrlKey];
    
    if (![detailVC.currentURL isEqualToString:webUrl] || forceUpdate)
        [detailVC onDidSetUrl:[NSURL URLWithString:webUrl]];
}

-(void)checkSignalingServerChange:(BOOL)forceUpdate
{
    SettingsViewController *masterVC = [self.splitViewController.viewControllers.firstObject topViewController];
    NSString *serverAddress = [[NSUserDefaults standardUserDefaults] objectForKey:kServerAddressKey];
    
    if (![[WebrtcSignallingController sharedInstance].serverAddress isEqualToString:serverAddress] || forceUpdate)
    {
        // user settings controller to re-connect (as it implements webrtc delegate, etc.
        [masterVC connect:serverAddress];
    }
}

@end
