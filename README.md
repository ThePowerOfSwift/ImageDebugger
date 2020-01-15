## ImageDebugger

The trouble with developing augmented reality and live image processing apps is that you often have to test specific frames of the camera's input for debugging purposes. Were the contours drawn? Is the perspective fixed? Do I need to adjust this threshold?

iOS debugging tools require you to set breakpoints and use quick look to see if the image/frame is processing in the way you intended. This stops the running of your app, it takes a long time, and often quick look inexplicably fails to capture any data. ImageDebugger solves this by capturing and storing any image at any part of the processing lifecycle, and uploading it to your Firebase Firestore server, which in turn feeds new images to a live web client you can run on your computer.
