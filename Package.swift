// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Athan",
    products: [
        .library(
            name: "Athan",
            targets: ["Athan"]
        )
    ],
    targets: [
        .target(
            name: "Athan",
            path: "Sources",
            exclude: ["Info.plist"]
        )
    ]
)
