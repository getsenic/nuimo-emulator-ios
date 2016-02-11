# Nuimo Emulator for iOS

The Nuimo emulator for iOS can be used as a replacement for a physical Nuimo device.

<img src="https://raw.githubusercontent.com/getsenic/nuimo-emulator-ios/master/screenshot.png" alt="Nuimo Emulator for iOS text" height="400">

<a href="https://github.com/getsenic/nuimo-emulator-android/">Looking for a Nuimo emulator for your Android device?</a>

## How to use

1. Clone this repository
2. Open the Xcode project (requires Xcode 7.2+)
3. Install the iOS app on your iOS device (requires iOS 8.0+)
4. Enable bluetooth to start advertising and allow for connections (= Nuimo power on)
5. Disable bluetooth to stop advertising and disconnect (= Nuimo power off)

## Notes

- Unlike Nuimo, the emulator continues to advertise when it is connected to a central device
- Restarting the app does not disconnect central devices until you actually disable bluetooth
- Fly events are not yet supported and will be added soon

## Support

For support, contact developers@senic.com or visit https://senic.com/developers
