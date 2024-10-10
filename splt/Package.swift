//// swift-tools-version:5.3
//import PackageDescription
//
//let package = Package(
//    name: "splt",
//    platforms: [.iOS(.v14)],
//    products: [
//        .library(name: "splt", targets: ["splt"]),
//    ],
//    dependencies: [
//        .package(name: "Firebase",
//                 url: "https://github.com/firebase/firebase-ios-sdk.git",
//                 from: "10.0.0")
//    ],
//    targets: [
//        .target(
//            name: "splt",
//            dependencies: [
//                .product(name: "FirebaseFirestoreSwift", package: "Firebase")
//            ]),
//    ]
//)
