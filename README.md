# WyzeSwift

A native Swift client for interacting with Wyze smart devices (plugs, switches, bulbs, etc.) via the Wyze Cloud API.

Built for the open-source smart home community by **ShortBridge** ([shortbridge.app](https://shortbridge.app)).

## Features

- ⚡️ Modern Swift Concurrency (`async`/`await`, `Sendable`).
- 🔒 No third-party dependencies (uses native `Foundation` and `CryptoKit`).
- 📱 Compatible with iOS 16+, macOS 13+, watchOS 9+, tvOS 16+.
- 🧩 Easy integration via Swift Package Manager.

## Installation

Add `WyzeSwift` to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/shortbridgeapp/wyze-swift.git", from: "1.0.0")
]
```

## Quick Start

```swift
import WyzeSwift

let client = WyzeClient()

// 1. Authenticate
let token = try await client.login(email: "user@example.com", password: "password123")

// 2. Discover Devices
let devices = try await client.getDevices(accessToken: token)
for device in devices {
    print("Found \(device.name) (\(device.mac))")
}

// 3. Control State (Turn On/Off)
if let plug = devices.first {
    try await client.setDeviceState(
        mac: plug.mac,
        model: plug.productModel,
        isOn: true,
        accessToken: token
    )
    print("Turned on \(plug.name)")
}
```

## Acknowledgements & Licensing

This project is open-sourced under the **GNU General Public License v3.0 (GPL-3.0)** in honor of the smart home reverse-engineering research and protocol documentation created by the open-source community (`wyzeapy`, `wyze-sdk`, and `docker-wyze-bridge`).

Wyze is a registered trademark of Wyze Labs, Inc. This project is an independent effort and is not affiliated with or endorsed by Wyze Labs, Inc.
