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

@interface AppDelegate ()

@property (nonatomic) UISplitViewController *splitViewController;

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.splitViewController = (UISplitViewController*)self.window.rootViewController;
    self.splitViewController.preferredDisplayMode = UISplitViewControllerDisplayModePrimaryHidden;
    
    SettingsViewController *masterVC = [self.splitViewController.viewControllers.firstObject topViewController];
    ViewController *detailVC = self.splitViewController.viewControllers.lastObject;
    
    masterVC.delegate = detailVC;
    
    return YES;
}


- (void)applicationWillResignActive:(UIApplication *)application {
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


@end
