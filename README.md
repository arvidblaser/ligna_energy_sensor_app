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
    flutter pub add supabase_flutter


Koda koden
Fixa Andoid Manifest
Fixa assets i pubspec.yaml

Bygga release: flutter build appbundle

## köra linux på windows (wsl)
wsl --install
starta om o se tt användaren skapas för ubuntu (arvid / arvid) som test här
installera wsl-extension och öppna remote ubuntu / wsl och öppna mappen

aktivera flutter extension
testa: which flutter (ska vara från home-folder och inte på windows c)

````
arvid@WIN-6K66PO3E76Q:~$ echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.bashrc
arvid@WIN-6K66PO3E76Q:~$ source ~/.bashrc
arvid@WIN-6K66PO3E76Q:~$ which flutter
/mnt/c/flutter/bin/flutter
arvid@WIN-6K66PO3E76Q:~$ echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.bashrc
arvid@WIN-6K66PO3E76Q:~$ source ~/.bashrc
arvid@WIN-6K66PO3E76Q:~$ which flutter
/home/arvid/flutter/bin/flutter
arvid@WIN-6K66PO3E76Q:~$ 
````
Slutsats: Funkar att dra igång men hittar inte bluetooth adapter. Bättre att testa i native linux

## köra windows app
Funkade inte rakt av att ersätta alla fluttter_blue_plus med flutter_blue_plus windows

indvik weboptinal services
dart pub add flutter_blue_plus_windows
flutter pub add win_ble
Slutsats: inte värt besväret

## köra webapp
Funkar att hitta bluettooth-enheter.
Man kan "parkoppla" med en Ben, datan ser dock mystisk ut / saknas
Slutsats: kan vara värt att testa lite till men antagligen inte
OM man kollar så kan det ha att göra med         webOptionalServices: [

## Databas
Steg 1: Supabase, sign in på redan skapad användare ladda upp data
Steg 2: långsiktig arkitektur
    a) SignIn/SignUp skärm ->
    b) Hamburgermeny, signOut, scanScreen, databaseScreen

## köra raspberry pi
klona repot
sudo apt update && sudo apt upgrade -y
sudo apt install code 
sudo apt install clang
sudo apt install cmake
sudo apt install libgtk-3-dev
sudo apt install mesa-utils

nano ~/.bashrc
export PATH="$PATH:/home/admin/git/flutter/bin"
source ~/.bashrc