# Athan

Athan is a well tested and well documented library for calculating Islamic prayer times. This is a fork of [Adhan Swift](https://github.com/batoulapps/adhan-swift) with added customization.

## Installation

### Swift Package Manager

For [SPM](https://swift.org/package-manager/) add the following to your `Package.swift` file:

```swift
// swift-tools-version:4.2
dependencies: [
    .package(url: "https://github.com/qazwini/athan", .branch("main")),
]
```

### Manually

You can also manually add Athan.

- Download the source.
- Add Athan.xcodeproj as a subproject in your app's project.
- Drag Athan.framework to "Linked Frameworks and Libraries" in your app's target.


## Usage

To get prayer times initialize the `PrayerTimes` struct passing in coordinates,
date, and calculation parameters.

```swift
let prayerTimes = PrayerTimes(prayers: prayers, coordinates: coordinates, date: date, calculationParameters: params)
```
