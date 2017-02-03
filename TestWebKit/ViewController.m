//
//  ViewController.m
//  TestWebKit
//
//  Created by Peter Gusev on 11/9/16.
//  Copyright © 2016 Peter Gusev. All rights reserved.
//

#import "ViewController.h"
#import "SettingsViewController.h"
#import "WebrtcSignallingController.h"
#import <WebRTC/WebRTC.h>
#import "NSObject+NCAdditions.h"
#import <JavaScriptCore/JavaScriptCore.h>
#import <GLKit/GLKit.h>

NSString* const kServerReconnectNeeded = @"kServerReconnectNeeded";

NSString* const kJsHookApp = @"iosapp";
NSString* const kJsHookVideoVisibile = @"setVideoVisibility";   // 1 argument - video visibility (boolean)
NSString* const kJsHookSetServerAddress = @"setServerAddress";  // 1 argument - server address (<IP>:<port number>)
NSString* const kJsHookServerReconnect = @"serverReconnect";    // no arguments, reconnects to the previously set address
NSString* const kJsHookSetURL = @"setUrl";      // 1 argument - URL. does not load it
NSString* const kJsHookLoadURL = @"loadUrl";    // no arguments - loads previously set URL
NSString* const kJsHookSetVideoSize = @"setVideoSize";  // 2 arguments - width and height (normalized, scale [0,1])
NSString* const kJsHookOffsetVideo = @"setVideoOffset"; // 2 arguments - xoffset and yoffset (normalized, scale [0,1])
NSString* const kJsHookCaptureScreenshot = @"captureScreen"; // no arguments

static RTCPeerConnectionFactory *peerConnectionFactory;

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UIWebView *webView;
@property (nonatomic) RTCPeerConnection *peerConnection;
@property (nonatomic,weak) IBOutlet RTCEAGLVideoView *renderingView;
@property (nonatomic) RTCMediaConstraints *constraints;
@property (nonatomic) RTCVideoTrack *track;
@property (nonatomic) JSContext *jsContext;
@property (nonatomic) CADisplayLink *displayLink;
@property (nonatomic) BOOL requestedScreenshot;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // set webview bg color
    // (make sure your html is transparent also)
    self.webView.opaque = NO;
    self.webView.backgroundColor = [UIColor clearColor];
    self.webView.delegate = self;
    
    // disable scrolling
    self.webView.scrollView.scrollEnabled = NO;
    
//    [self setupTestPage];
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        peerConnectionFactory = [[RTCPeerConnectionFactory alloc] init];
    });
    
    [self setupPeerConnection];
    
    self.renderingView.delegate = self;
    
    [self subscribeForNotificationsAndSelectors:
     kWebrtcControllerProducerDisconnectedNotification, @selector(onProducerStateChanged:),
     kWebrtcControllerProducerConnectedNotificaiton, @selector(onProducerStateChanged:),
     kWebrtcControllerGotOfferNotification, @selector(onReceivedOffer:),
     kWebrtcControllerIceCandidatesNotification, @selector(onReceivedIceCandidate:),
     nil];
    
    self.requestedScreenshot = NO;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// SettingsViewControllerDelegate
-(void)onDidSetSignallingServer:(NSString *)ipAddress
{
}

-(void)onDidSetUrl:(NSURL *)urlAddress
{
    [self.webView loadRequest:[NSURLRequest requestWithURL:urlAddress]];
}

-(void)onDidChooseTestPage
{
    [self setupTestPage];
}

-(NSString *)currentURL
{
    return self.webView.request.URL.absoluteString;
}

#pragma mark - private
-(void)setupJsHooks
{
    self.jsContext = [self.webView valueForKeyPath:@"documentView.webView.mainFrame.javaScriptContext"];
    self.jsContext[@"console"][@"log"] = ^(JSValue *msg) {
        NSLog(@"JAVASCRIPT CONSOLE.LOG: %@", msg);
    };
    
    self.jsContext[kJsHookApp] = self;
    
    self.jsContext[kJsHookApp][kJsHookVideoVisibile] = ^(JSValue *visibility){
        BOOL videoVisibility = [visibility toBool];
        NSLog(@"setting video visibility to %@", (videoVisibility ? @"VISIBLE" : @"HIDDEN"));
        self.renderingView.hidden  = !videoVisibility;
    };
    
    self.jsContext[kJsHookApp][kJsHookSetServerAddress] = ^(JSValue *serverAddress){
        [[NSUserDefaults standardUserDefaults] setValue:[serverAddress toString] forKey:kServerAddressKey];
    };
    
    self.jsContext[kJsHookApp][kJsHookServerReconnect] = ^(){
        [[NSNotificationCenter defaultCenter] notifyNowWithNotificationName:kServerReconnectNeeded andUserInfo:nil];
    };
    
    self.jsContext[kJsHookApp][kJsHookSetURL] = ^(JSValue *url){
        [[NSUserDefaults standardUserDefaults] setValue:[url toString] forKey:kWebpageUrlKey];
    };
    
    self.jsContext[kJsHookApp][kJsHookLoadURL] = ^(){
        NSURL *url = [NSURL URLWithString:[[NSUserDefaults standardUserDefaults] stringForKey:kWebpageUrlKey]];
        [self onDidSetUrl:url];
    };
    
    self.jsContext[kJsHookApp][kJsHookSetVideoSize] = ^(JSValue *width, JSValue *height){
        CGSize parentView = self.view.bounds.size;
        CGRect videoRect = CGRectMake(self.renderingView.frame.origin.x, self.renderingView.frame.origin.y,
                                      [width toDouble]*parentView.width, [height toDouble]*parentView.height);
        [self.renderingView setFrame:videoRect];
    };
    
    self.jsContext[kJsHookApp][kJsHookOffsetVideo] = ^(JSValue *xoff, JSValue *yoff){
        CGSize parentView = self.view.bounds.size;
        CGRect videoRect = CGRectMake([xoff toDouble]*parentView.width, [yoff toDouble]*parentView.height,
                                      self.renderingView.frame.size.width, self.renderingView.frame.size.height);
        [self.renderingView setFrame:videoRect];
    };
    
    self.jsContext[kJsHookApp][kJsHookCaptureScreenshot] = ^(){
        self.requestedScreenshot = YES;
        [self setupCaLink];
    };
}

-(void)setupTestPage
{
    // load page
    NSError *err;
    [self.webView loadHTMLString:[NSString stringWithContentsOfFile:
                                  [[NSBundle mainBundle] pathForResource:@"test"
                                                                  ofType:@"html"]
                                                           encoding:NSUTF8StringEncoding
                                                              error:&err]
                         baseURL:[[NSBundle mainBundle] resourceURL]];
    
}

-(void)setupPeerConnection
{
    RTCConfiguration *configuration = [[RTCConfiguration alloc] init];
    configuration.iceServers = @[[[RTCIceServer alloc] initWithURLStrings:@[@"stun:stun.l.google.com:19302"]]];
    
    self.constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:nil
//  @{
//                                                                                   @"OfferToReceiveVideo":@"false"
//                                                                                   @"OfferToReceiveAudio":@"false"
//                                                                                   }
                                                             optionalConstraints:@{@"DtlsSrtpKeyAgreement":@"true"}];
    self.peerConnection = [peerConnectionFactory peerConnectionWithConfiguration:configuration
                                                                     constraints:self.constraints
                                                                        delegate:self];
}

-(void)setupCaLink
{
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(onCaLinkCallback:)];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
}

-(void)onCaLinkCallback:(CADisplayLink *)sender
{
    if (self.requestedScreenshot)
    {
        self.requestedScreenshot = NO;
        [self captureScreen];
        [self.displayLink invalidate];
        self.displayLink = nil;
    }
}

-(void)captureScreen
{
    GLKView *renderView  = self.renderingView.subviews[0];
    assert([renderView isKindOfClass:[GLKView class]]);
    
    UIImage *img = [renderView snapshot];
    UIImageWriteToSavedPhotosAlbum(img, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
}

- (void)               image: (UIImage *) image
    didFinishSavingWithError: (NSError *) error
                 contextInfo: (void *) contextInfo
{
    if (error)
        NSLog(@"couldn't save screenshot due to an error: %@", error);
}

#pragma mark - RTCPeerConnectionDelegate
/** Called when the SignalingState changed. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection
didChangeSignalingState:(RTCSignalingState)stateChanged
{
    NSLog(@"signaling state changed: %ld", (long)stateChanged);
}

/** Called when media is received on a new stream from remote peer. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection didAddStream:(RTCMediaStream *)stream
{
    NSLog(@"new stream. audio tracks %lu, video tracks %lu",
          (unsigned long)stream.audioTracks.count, (unsigned long)stream.videoTracks.count);
    self.track = stream.videoTracks.lastObject;
    [self.track addRenderer:self.renderingView];
    
    NSError *err = nil;
    [[AVAudioSession sharedInstance] setActive:NO error:&err];
    
    if (err)
        NSLog(@"failed to deactivate audio session: %@", err);
}

/** Called when a remote peer closes a stream. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection
       didRemoveStream:(RTCMediaStream *)stream
{
    NSLog(@"remote peer closed stream");
}

/** Called when negotiation is needed, for example ICE has restarted. */
- (void)peerConnectionShouldNegotiate:(RTCPeerConnection *)peerConnection
{
    NSLog(@"negotiation needed");
}

/** Called any time the IceConnectionState changes. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection
didChangeIceConnectionState:(RTCIceConnectionState)newState
{
    NSLog(@"ice connection state changed: %ld", (long)newState);
}

/** Called any time the IceGatheringState changes. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection
didChangeIceGatheringState:(RTCIceGatheringState)newState
{
    NSLog(@"ice gathering state changed: %ld", (long)newState);
}

/** New ice candidate has been found. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection
didGenerateIceCandidate:(RTCIceCandidate *)candidate
{
    NSLog(@"ice candidate has been found");
    [[WebrtcSignallingController sharedInstance] sendIceCandidate:@{
                                                                    @"candidate":candidate.sdp,
                                                                    @"sdpMLineIndex":@(candidate.sdpMLineIndex),
                                                                    @"sdpMid":candidate.sdpMid}];
}

/** Called when a group of local Ice candidates have been removed. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection
didRemoveIceCandidates:(NSArray<RTCIceCandidate *> *)candidates
{
    NSLog(@"did remove ice candidate");
}

/** New data channel has been opened. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection
    didOpenDataChannel:(RTCDataChannel *)dataChannel
{
    NSLog(@"did open data channel");
}

#pragma mark - notifications
-(void)onProducerStateChanged:(NSNotification*)notification
{
    if ([notification.name isEqualToString:kWebrtcControllerProducerDisconnectedNotification])
    {
        [self.peerConnection close];
        self.peerConnection = nil;
    }
    else
        [self setupPeerConnection];
}

-(void)onReceivedOffer:(NSNotification*)notification
{
    __weak ViewController *this = self;
    NSString *sdp = notification.userInfo[kWebrtcControllerOfferKey];
    
    NSLog(@"received offer:\n%@", sdp);
    
    [self.peerConnection setRemoteDescription:[[RTCSessionDescription alloc] initWithType:RTCSdpTypeOffer sdp:sdp]
                            completionHandler:^(NSError * _Nullable error) {
                                NSLog(@"set remote description. error %@", error);
                                [this.peerConnection answerForConstraints:this.constraints
                                                        completionHandler:^(RTCSessionDescription* sdp, NSError * error) {
                                                            [this.peerConnection setLocalDescription:sdp completionHandler:^(NSError* error) {
                                                                NSLog(@"set local description: %@", sdp);
                                                                [[WebrtcSignallingController sharedInstance] sendSdpAnswer:@{
                                                                                                                             @"type":@"answer",
                                                                                                                             @"sdp":sdp.sdp}];
                                                            }];
                                                        }];
                            }];
}

-(void)onReceivedIceCandidate:(NSNotification*)notification
{
    NSArray *candidates = notification.userInfo[kWebrtcControllerIceCandidatesKey];
    
    for (NSDictionary *candidate in candidates)
    {
        RTCIceCandidate *c = [[RTCIceCandidate alloc] initWithSdp:candidate[@"candidate"]
                                                    sdpMLineIndex:[candidate[@"sdpMLineIndex"] integerValue]
                                                           sdpMid:candidate[@"sdpMid"]];
        
        NSLog(@"setting ICE. signalling state %ld, ice connection state %ld, ice gathering state %ld",
              (long)self.peerConnection.signalingState,
              (long)self.peerConnection.iceConnectionState,
              (long)self.peerConnection.iceGatheringState);
        
        [self.peerConnection addIceCandidate:c];
    }
}

#pragma mark - RTCEAGLVideoViewDelegate
- (void)videoView:(RTCEAGLVideoView *)videoView didChangeVideoSize:(CGSize)size
{
    
}

#pragma mark - UIWebView delegate
-(void)webViewDidFinishLoad:(UIWebView *)webView
{
    [self setupJsHooks];
}

-(void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    NSLog(@"Can't load provided URL due to an error: %@", error);
}

@end
