//
//  SettingsViewController.m
//  TestWebKit
//
//  Created by Peter Gusev on 12/7/16.
//  Copyright © 2016 Peter Gusev. All rights reserved.
//

#import "SettingsViewController.h"
#import "WebrtcSignallingController.h"
#import "NSObject+NCAdditions.h"
#import "ViewController.h"

NSString* const kServerAddressKey = @"serverAddress";
NSString* const kWebpageUrlKey = @"webpageUrl";

@interface SettingsViewController ()

@property (weak, nonatomic) IBOutlet UITextField *ipAddressField;
@property (weak, nonatomic) IBOutlet UILabel *serverConnectionLabel;
@property (weak, nonatomic) IBOutlet UITextField *webpageUrlField;
@property (weak, nonatomic) IBOutlet UILabel *producerStatusLabel;

@end

@implementation SettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self loadDataFromDefaults];
    
    self.serverConnectionLabel.text = @"disconnected";
    [self subscribeForNotificationsAndSelectors:
     kWebrtcControllerGotIdNotificaiton, @selector(onReceivedId:),
     kWebrtcControllerProducerConnectedNotificaiton, @selector(onProducerStatusChanged:),
     kWebrtcControllerProducerDisconnectedNotification, @selector(onProducerStatusChanged:),
     kServerReconnectNeeded, @selector(onReconnectRequested:),
     nil];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self loadDataFromDefaults];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)onTestPageTap:(id)sender {
    if ([self.delegate respondsToSelector:@selector(onDidChooseTestPage)])
        [self.delegate onDidChooseTestPage];
}

- (IBAction)onReloadTap:(id)sender {
    if ([self.delegate respondsToSelector:@selector(onDidSetUrl:)])
    {
        NSURL *url = [NSURL URLWithString: [[NSUserDefaults standardUserDefaults] stringForKey:kWebpageUrlKey]];
        [self.delegate onDidSetUrl:url];
    }
}

- (IBAction)onConnectTap:(id)sender {
    [self connect: self.ipAddressField.text];
}

- (IBAction)serverAddressChanged:(id)sender {
    [[NSUserDefaults standardUserDefaults] setObject:[sender text] forKey:kServerAddressKey];
}

- (IBAction)onWebpageUrlChanged:(id)sender {
    [[NSUserDefaults standardUserDefaults] setObject:[sender text] forKey:kWebpageUrlKey];
}

-(void)connect:(NSString*)serverAddress
{
    NSString *ip = serverAddress;
    NSUInteger portNum = 3001;
    
    NSArray *comps = [ip componentsSeparatedByString:@":"];
    
    if (comps.count > 1)
    {
        NSString *portStr = [comps lastObject];
        portNum = [portStr integerValue];
        ip = [comps firstObject];
    }
    
    [[WebrtcSignallingController sharedInstance] connectTo:ip
                                                    atPort:portNum
                                              withCallback:^(NSError *e) {
                                                  dispatch_async(dispatch_get_main_queue(), ^{
                                                      if (e)
                                                      {
                                                          self.serverConnectionLabel.text = [NSString stringWithFormat:@"error: %@",
                                                                                             (e.userInfo[kWebrtcControllerErrorMessageKey]?e.userInfo[kWebrtcControllerErrorMessageKey]:e.localizedDescription)];
                                                          self.producerStatusLabel.text = @"unknown";
                                                          self.producerStatusLabel.textColor = [UIColor blackColor];
                                                      }
                                                      else
                                                      self.serverConnectionLabel.text = @"connected";
                                                  });
                                                  
                                              }];
    self.serverConnectionLabel.text = @"trying...";
}

#pragma mark - private
-(void)loadDataFromDefaults
{
    if ([[NSUserDefaults standardUserDefaults] objectForKey:kServerAddressKey])
        self.ipAddressField.text = [[NSUserDefaults standardUserDefaults] objectForKey:kServerAddressKey];
//        [self onConnectTap:nil];
    else
        self.ipAddressField.text = @"192.168.0.1:3001";
    
    if ([[NSUserDefaults standardUserDefaults] objectForKey:kWebpageUrlKey])
        self.webpageUrlField.text = [[NSUserDefaults standardUserDefaults] objectForKey:kWebpageUrlKey];
}

#pragma mark - notificaitons
-(void)onReceivedId:(NSNotification*)notificaiton
{
    NSString *idString = notificaiton.userInfo[kWebrtcControllerIdKey];
    self.serverConnectionLabel.text = [NSString stringWithFormat:@"connected as %@", idString];
}

-(void)onProducerStatusChanged:(NSNotification*)notification
{
    if ([notification.name isEqualToString:kWebrtcControllerProducerConnectedNotificaiton])
    {
        self.producerStatusLabel.text = @"connected";
        self.producerStatusLabel.textColor = [UIColor greenColor];
    }
    else
    {
        self.producerStatusLabel.text = @"disconnected";
        self.producerStatusLabel.textColor = [UIColor redColor];
    }
}

-(void)onReconnectRequested:(NSNotification*)notification
{
    [self connect:[[NSUserDefaults standardUserDefaults] stringForKey:kServerAddressKey]];
}

@end
