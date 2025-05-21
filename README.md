# Ligna Energy Sensor App

Repo for Flutter-app som skannar data med BLE och visar upp resultatetsnyggt

## Process för att återupprepa allt igen

ctrl shift p -> flutter create app
git init
byta namn i android manifet, + byta namespace https://stackoverflow.com/questions/77828097/changing-applicationid-and-namespace-in-build-gradle-causes-error
fixa med cert bygga enligt guide: https://docs.flutter.dev/deployment/android

fixa resten av dependecies + flutter uppdatering
    flutter upgrade - i android studio behövde jag uppdatera NDK
    dart pub add intl
    flutter pub add share_plus
    flutter pub add path_provider
    flutter pub add flutter_blue_plus
    flutter pub add flutter_launcher_icons
    dart run flutter_launcher_icons:generate (ändra i yamlfilen till var filerna ligger)
    flutter pub run flutter_launcher_icons
