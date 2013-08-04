# PebbleWeatherIO

PebbleWeatherIO is an example iOS and Pebble app that utilizes the [Forecast.IO API](https://developer.forecast.io/docs/v2) to show the current weather conditions on both the watch and the phone.

![PebbleWeatherIO Screenshot](https://github.com/mmorey/PebbleWeatherIO/raw/master/screenshot.jpg)

## Usage

_**Important note, demo does not work on the iOS simulator**: simulator cannot connect with Pebble watch thus you must run the iOS app on an actual device._

See Xcode workspace in `/iOS` folder for the iOS app. See `Pebble.c` in the `/Pebble` folder for the Pebble watch face app. iOS app requires a Forecast.io [API key](https://developer.forecast.io/) in order to work. Once you have an API key just create a `PWForecastIOAPI.[h|m]` file with the following line in your project. Be sure to replace the dummy key below with your actual key.

```objective-c
NSString *const kFCAPIKey = @"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX";
```

## Credits

PebbleWeatherIO is brought to you by [Matthew Morey](http://matthewmorey.com). The icons included with the iOS project are from [GLYPHICONS](http://glyphicons.com/). If you have feature suggestions or bug reports, feel free to help out by sending pull requests or by [creating new issues](https://github.com/mmorey/PebbleWeatherIO/issues/new). If you're using PebbleWeatherIO in your project, attribution would be nice.
