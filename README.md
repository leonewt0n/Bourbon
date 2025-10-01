<div align="center">
  
  # Bourbon 🥃
  *Barrel-aged Whisky*
  
</div>

<div align="center">
  <img width="750" alt="New Bottle" src="https://github.com/leonewt0n/Bourbon/blob/main/bourbonScreenshot.png">

</div>


---

Bourbon provides a clean and easy to use graphical wrapper for Wine built in native SwiftUI. You can make and manage bottles, install and run Windows apps and games, and unlock the full potential of your Mac with no technical knowledge required. Whisky is built on top of Gcenx's Wine 10, and Apple's own `Game Porting Toolkit`.

---
## System Requirements
- CPU: Apple Silicon (M-series chips)
- OS: macOS Sonoma 14.0 or later

## Build
* Install .pkg to get swiftlint https://github.com/realm/SwiftLint/releases
* Open Bourbon.xcodeproj in Xcode
* Adjust signing
* Click Play button

---
## Wine Compilation 
* Download Gcenx Wine from https://github.com/Gcenx/macOS_Wine_builds/releases
* Extract out wine folder and rename to Wine and place in $HOME/Library/Application Support/com.leonewton.Bourbon/Libraries/
* Download https://github.com/3Shain/dxmt
* Follow directions to install dxmt https://github.com/3Shain/dxmt/wiki/DXMT-Installation-Guide-for-Geeks
* Download Apple's Game Porting Toolkit Redist with D3DMetal https://developer.apple.com/games/game-porting-toolkit/
* place external folder in wine lib folder
* Install [GStreamer](https://gstreamer.freedesktop.org/data/pkg/osx/1.26.5/gstreamer-1.0-1.26.5-universal.pkg)
---

## Credits & Acknowledgments

Whisky is possible thanks to the magic of several projects:

- [msync](https://github.com/marzent/wine-msync) by marzent
- [DXVK-macOS](https://github.com/Gcenx/DXVK-macOS) by Gcenx and doitsujin
- [MoltenVK](https://github.com/KhronosGroup/MoltenVK) by KhronosGroup
- [Sparkle](https://github.com/sparkle-project/Sparkle) by sparkle-project
- [SemanticVersion](https://github.com/SwiftPackageIndex/SemanticVersion) by SwiftPackageIndex
- [swift-argument-parser](https://github.com/apple/swift-argument-parser) by Apple
- [SwiftTextTable](https://github.com/scottrhoyt/SwiftyTextTable) by scottrhoyt
- [CrossOver 22.1.1](https://www.codeweavers.com/crossover) by CodeWeavers and WineHQ
- D3DMetal by Apple
- [Whiskey.app](https://github.com/Whisky-App/Whisky) 

Special thanks to Gcenx, ohaiibuzzle, and Nat Brown for their support and contributions!

---


