# CommandSwipeMover

CommandSwipeMover is a small macOS menu-bar utility.

Gesture:

- Hold Command.
- Swipe left or right with three fingers on the trackpad.
- The focused window from the current app moves to the next display in that direction and fills that display.
- Swipe down with three fingers without holding Command.
- WhatsApp opens immediately in the center of the monitor under the pointer. Swipe down again to hide it.
- If Mission Control was opened with a three-finger swipe up, the next three-finger swipe down is passed through to macOS so Mission Control can close instead of opening WhatsApp.

Notes:

- The app needs macOS Accessibility permission to move other apps' windows.
- The app needs Input Monitoring permission to detect trackpad gestures.
- The first version fills the destination monitor using the Accessibility API. It does not force every app into macOS Spaces-native fullscreen, because that behavior is app-specific and less reliable.
- The gesture detector is isolated so more gestures and actions can be added later.

Build:

```sh
swift build -c release
```

Package the app bundle after building:

```sh
mkdir -p CommandSwipeMover.app/Contents/MacOS
cp AppBundle/Info.plist CommandSwipeMover.app/Contents/Info.plist
cp .build/arm64-apple-macosx/release/CommandSwipeMover CommandSwipeMover.app/Contents/MacOS/CommandSwipeMover
codesign --force --sign - CommandSwipeMover.app
```
