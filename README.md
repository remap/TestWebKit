TestWebKit is a test iOS application that allows to receive live video streams from web-clients using WebRTC. For the client part, see the code at https://github.com/remap/comhall-webrtc/ .

## Dependencies
* WebRTC
* MobileVLC Kit
* SocketIO framework

MobileVLC Kit and SocketIO framework are handled automatically using Cocoapods. Compiled WebRTC framework for iOS comes with this repo. It is, however, an old build (2017) but it works. If you need to update WebRTC framework for any reason, you’ll need to build it from source yourself. Consulr webrtc.org on more information how to do it.

### Project setup
The *TestWebKit.xcworkspace* workspace includes subproject for TestWebKit and Cocoapods dependency project. Before trying to build, go to the repo directory in the terminal and type:

```
pod install
```

This will pull dependencies and re-configure the workspace.
Once this is done, open *TestWebKit.xcworkspace* and fix path for the WebRTC framework you compiled in the previous step:

1. In project navigator go to /Frameworks/
2. Select /WebRTC.framework/
3. In file inspector, specify correct path for the framework.

## Build
1. Open  *TestWebKit.xcworkspace*
2. Plugin iOS device
3. In Xcode, select your device as build target
4. Build the project

> ⚠️
> Step 3 is crucial. If you try to build for simulator, your build will fail at linking stage, because WebRTC framework is not compiled for Simulator (x64 architecture).

## Deployment
In order to deploy the project:
1. Build project for /Archive/
2. Open Xcode /Organizer/ window
3. Select TestWbkit project in the Archives tab
4. Click /Distribute App/ and follow instructions for app publishing.

> ⚠️
> If you publish your app into App Store Connect, you’ll need to update project’s build number before you build app for distribution.
