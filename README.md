# RD Photo & Signature Resizer

Android-first Flutter app for resizing passport photos and signatures.

## Features
- Select one or multiple images from Gallery or take a photo with Camera
- Crop and rotate images
- Resize by custom pixel width and height, percentage, and common photo presets
- Signature dimension presets (140×60, 300×100, 600×200) plus custom dimensions
- Compress JPG toward a target size from 10 KB to 2 MB; enter values in KB or MB
- JPG/JPEG, PNG, and WEBP output
- Square / aspect-ratio fitting: crop-to-fill, white padding, and normal resize
- Preview output dimensions and file size in KB and MB
- Save to a user-selected location or the RD Photo Resizer Gallery album
- Share resized images and share the latest APK file link
- Bengali / English interface and saved settings
- Offline image processing; selected photos are not uploaded to a server
- In-app GitHub release update check and APK installer handoff
- Govt Job with RD YouTube link

## Important notes
- Target-KB compression is for JPG. PNG and WEBP use their format encoders and may not match a requested KB target.
- Target size is best-effort; exact file size depends on image detail and dimensions.
- APK installation and updating require Android's confirmation and may require allowing installs from the app used to open the APK.
- The app uses Google's AdMob test application ID in the Android manifest. Replace it with your own AdMob IDs before production monetization.

## Build APK
GitHub Actions builds the release APK on pushes to `main`. Open the latest successful **Build and publish RD Photo Resizer** workflow run or the GitHub Releases page to download `app-release.apk`.

## Privacy
Images are processed locally on the device. The app does not upload selected photos or signatures to a server.

Always check the relevant recruitment notice for exact photo and signature specifications.
