# freesk8_mobile

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://flutter.dev/docs/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://flutter.dev/docs/cookbook)

For help getting started with Flutter, view our
[online documentation](https://flutter.dev/docs), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Ok, for reals

This was my first flutter project and introduction to mobile app development. Code was produced
quickly, best practices were not always known and many lessons were learned the hard way.

The current structure of the application follows; hopefully it is of some assistance as you
navigate the sources.

```
/lib
|
├ /components
|   └ Classes to support the main application
├ /hardwareSupport
|   └ Classes to suport hardware components like VESC, FlexiBMS and DieBieMS
├ /mainViews
|   └ The four main tabs of the application
|       └ connectionStatus
|       |   └ Connect to BLE devices and display Robogotchi status
|       └ realTimeData
|       |   └ Real time ESC telemetry
|       |   └ Real time smart BMS telemetry
|       └ esk8Configuration
|       |   └ FreeSK8 Application Settings
|       |   └ ESC Speed Profiles
|       |   └ ESC Application Configuration (Input setup)
|       |   └ ESC Motor Configuration
|       └ rideLogging
|            └ Display rides logged in calendar or list view
├ /subViews
|   └ Full screen views that overlay the main application
|       └ escProfileEditor
|       └ focWizard
|       └ rideLogViewer
|       └ robogotchiCfgEditor
|       └ robogotchiDFU
└ /widgets
    └ Custom widgets that are used in the application
```
