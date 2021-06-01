# freesk8_mobile

A Flutter project to enhance connectivity to your ESK8 or PEV.

This project also serves as a companion application to the [FreeSK8 Robogotchi](https://derelictrobot.com/collections/production/products/freesk8-robogotchi).

## Getting Started

This project was a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://flutter.dev/docs/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://flutter.dev/docs/cookbook)

For help getting started with Flutter, view their
[online documentation](https://flutter.dev/docs), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Ok, for reals

This was my first flutter project and introduction to mobile app development. Code was produced
quickly, best practices were not always known and many lessons were learned the hard way.

The current structure of the application follows. Hopefully it is of some assistance as you
navigate the sources.

```
/lib
|
├ /components
|   └ Classes to support the main application
├ /hardwareSupport
|   └ Classes to support hardware components like VESC, FlexiBMS and DieBieMS
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

<!-- LICENSE -->
## License

(C) Copyright 2021 - FreeSK8 Foundation NPO

**Licensed under GNU General Public License v3.0**

<!-- CONTACT -->
## Authors

* Renee Glinski - [@r3n33](https://github.com/r3n33)
* Andrew Dresner - [@DerelictRobot](https://github.com/DerelictRobot)
* Project Link: [https://github.com/FreeSK8](https://github.com/FreeSK8)

 <!-- CONTRIBUTING -->
## Contributing

Contributions are what make the open source community such an amazing place to be learn, inspire, and create. Any contributions you make are **greatly appreciated**.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request


<!-- ACKNOWLEDGEMENTS -->
## Attribution & References

* [VESC-Project](https://vesc-project.com)
* [Flutter Lab: Write your first Flutter app](https://flutter.dev/docs/get-started/codelab)
* [Flutter Cookbook: Useful Flutter samples](https://flutter.dev/docs/cookbook)
* [pub.dev](https://pub.dev/)
