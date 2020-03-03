# ImageDebugger

The trouble with developing augmented reality and live image processing apps is that you often have to test specific frames of the camera's input for debugging purposes. Were the contours drawn? Is the perspective fixed? Do I need to adjust this threshold?

With iOS debugging, you set breakpoints and use quick look to see if the image is processing in the way you intended. This stops the running of your app, it's tedious and slow, and often quick look inexplicably fails to capture any data. ImageDebugger solves this by capturing and storing any image at any part of the processing lifecycle and uploading it to your Firebase Firestore server, which in turn feeds new images to a live web client you can run on your computer.

## How it works

- Code: One class in Swift (`ImageDebugger`) that you can download and drop into your project, for near-instantaneous use. You can find it at [ImageDebuggerExample/ImageDebuggerExample/ImageDebugger.swift](ImageDebuggerExample/ImageDebuggerExample/ImageDebugger.swift).

- Dependencies: Any images you log are uploaded to Firebase Cloud Storage, and the references to each image are stored and organized in Firestore. If using CocoaPods, add `pod 'Firebase/Firestore'` and `pod 'Firebase/Storage'` to your Podfile.

- Firebase: To setup your own Cloud Storage and Firestore instances, [create a new project](http://console.firebase.google.com) with Firebase and perform the iOS setup procedures (adding the GoogleService-Info.plist to your Xcode project and so on). Provision a Firestore instance and Cloud Storage instance, rules as you like—I kept everything in test mode with no authentication.

- Web Client: Use [MAMP](https://www.mamp.info/en/) or your favorite localhost tool to setup a server for the /Web directory, which will display all the images as you log them. The only change you need to make is in `index.html`, adding your own Firebase configuration code (which can be obtained by creating a new web app in the Firebase console).

## Example

Try the ImageDebuggerExample project to get a sense of how ImageDebugger works. The example uses OpenCV to analyze the edges in every frame that comes in from the camera. It uses ImageDebugger to ensure that all the processing is happening correctly. Run `pod install` before building the project.

**iOS app and web client configured in Firebase:**

<img src="https://raw.githubusercontent.com/shaandsingh/ImageDebugger/master/READMEAssets/AppsInFirebase.png" width="432">

**ImageDebuggerExample app detects edges in real-time:**

<img src="https://raw.githubusercontent.com/shaandsingh/ImageDebugger/master/READMEAssets/iOSApp.png" width="375">

**ImageDebugger class stores logged images in Cloud Storage:**

<img src="https://raw.githubusercontent.com/shaandsingh/ImageDebugger/master/READMEAssets/Storage.png">

**And additional metadata in Firestore:**

<img src="https://raw.githubusercontent.com/shaandsingh/ImageDebugger/master/READMEAssets/Firestore.png">

**Logged images are displayed on web client:**

<img src="https://raw.githubusercontent.com/shaandsingh/ImageDebugger/master/READMEAssets/Web1.png">

<img src="https://raw.githubusercontent.com/shaandsingh/ImageDebugger/master/READMEAssets/Web2.png">
