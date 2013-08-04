//
//  PWViewController.m
//  PebbleWeather
//
//  Created by Matthew Morey on 7/27/13.
//  Copyright (c) 2013 Matthew Morey. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "PWViewController.h"
#import "Forecastr+CLLocation.h"
#import "PWLocationManager.h"
#import <PebbleKit/PebbleKit.h>
#import "PWForecastIOAPI.h"
#import "PWWatchInfoViewController.h"

#define kKeyWatchIcon @(0)
#define kKeyWatchTemperature @(1)
#define kKeyWatchRequestUpdate @(2)

@interface PWViewController () <FCLocationManagerDelegate, PBPebbleCentralDelegate> {
    
    BOOL _forecastSyncIsFinished;
    BOOL _watchIsConnected;
    
}

@property (nonatomic, strong) PWLocationManager *locationManager;
@property (nonatomic, strong) Forecastr *forecastrManager;
@property (nonatomic, strong) PBPebbleCentral *pebbleManager;
@property (nonatomic, strong) PBWatch *watch;

@property (weak, nonatomic) IBOutlet UILabel *currentUpdateTimestampLabel;
@property (weak, nonatomic) IBOutlet UILabel *currentLocationLabel;
@property (weak, nonatomic) IBOutlet UILabel *currentTemperatureLabel;
@property (weak, nonatomic) IBOutlet UILabel *currentSummaryLabel;
@property (weak, nonatomic) IBOutlet UIButton *refreshButton;
@property (weak, nonatomic) IBOutlet UIButton *watchButton;

@property (nonatomic, strong) NSString *currentConditionsTemperature;
@property (nonatomic, strong) NSString *currentConditonsWeatherIcon;

@property (nonatomic, strong) id updateHandler;

@end

@implementation PWViewController

#pragma mark - View Lifecycle

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
#if TARGET_IPHONE_SIMULATOR
    NSAssert(0, @"Does not work on simulator! Test on actual device.");
#endif
    
    // Initialize on screen labels
    [self setupPhoneDisplay];

    // Setup state variables and initialize
    // Forecast.io client
    _forecastSyncIsFinished = NO;
    _watchIsConnected = NO;
    self.forecastrManager.apiKey = kFCAPIKey;
    self.forecastrManager.units = kFCUSUnits;
    
    // Determine current location, dled
    // latest forcast data, update display
    [self refresh];
    
}

- (void)didReceiveMemoryWarning {
    
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc {
    
    self.locationManager.delegate = nil;
    
    [self.watch closeSession:nil];
    self.pebbleManager.delegate = nil;
    
}

#pragma mark - Lazy Initializers 

- (PWLocationManager *)locationManager {
    
    if (!_locationManager) {
        _locationManager = [PWLocationManager sharedManager];
        _locationManager.delegate = self;
    }
    return _locationManager;
    
}

- (Forecastr *)forecastrManager {
    
    if (!_forecastrManager) {
        _forecastrManager = [Forecastr sharedManager];
    }
    return _forecastrManager;
    
}

- (PBPebbleCentral *)pebbleManager {
    
    if (!_pebbleManager) {
        _pebbleManager = [PBPebbleCentral defaultCentral];
        _pebbleManager.delegate = self;
    }
    return _pebbleManager;
    
}

# pragma mark - PWLocationManagerDelegate

// We successfully acquired the user's location
// now lets get the forecast and name for the
// location
- (void)didAcquireLocation:(CLLocation *)location {
    
    [self forecastForLocation:location];
    [self.locationManager findNameForLocation:location];
    
}

// There was an error that prevented us from
// acquiring the location, show an error
// instead
- (void)didFailToAcquireLocationWithErrorMessage:(NSString *)errorMessage {
    
    [self showFatalErrorAlertTitle:@"Location Error" alertMessage:errorMessage];
    
}

// We found the location name or defaulted to
// localized coordinates
- (void)didFindLocationName:(NSString *)locationName {
    
    NSLog(@"Found location name to be: %@", locationName);
    self.currentLocationLabel.text = locationName;
    
}

#pragma mark - PBPebbleCentralDelegate

// A Pebble watch has connected to the phone
- (void)pebbleCentral:(PBPebbleCentral *)central watchDidConnect:(PBWatch *)watch isNew:(BOOL)isNew {
    
    NSLog(@"Watch Connected: %@", [watch name]);
    [self setTargetWatch:watch];
    
}

// A Pebble watch has disconnected from the phone
- (void)pebbleCentral:(PBPebbleCentral *)central watchDidDisconnect:(PBWatch *)watch {
    
    NSLog(@"Watch Disconnected: %@", [watch name]);
    if ([watch isEqual:self.watch]) {
        [self setTargetWatch:nil];
        [self updateWatchIcon];
    }
    
}

#pragma mark - Pebble Watch

- (void)setTargetWatch:(PBWatch*)watch {
    
    if (!watch) {
        _watchIsConnected = NO;
    }
    
    self.watch = watch;
    
    // NOTE:
    // For demonstration purposes, we start communicating with the watch immediately upon connection,
    // because we are calling -appMessagesGetIsSupported: here, which implicitely opens the communication session.
    // Real world apps should communicate only if the user is actively using the app, because there
    // is one communication session that is shared between all 3rd party iOS apps.
    
    // Test if the Pebble's firmware supports AppMessages / Weather:
    [watch appMessagesGetIsSupported:^(PBWatch *watch, BOOL isAppMessagesSupported) {
        if (isAppMessagesSupported) {
            
            // Configure our communications channel to target the weather app:
            uint8_t bytes[] = {0x42, 0xc8, 0x6e, 0xa4, 0x1c, 0x3e, 0x4a, 0x07, 0xb8, 0x89, 0x2c, 0xcc, 0xca, 0x91, 0x41, 0x98};
            NSData *uuid = [NSData dataWithBytes:bytes length:sizeof(bytes)];
            [watch appMessagesSetUUID:uuid];
            
            NSString *message = [NSString stringWithFormat:@"Yay! %@ supports AppMessages :D", [watch name]];
            NSLog(@"%@", message);
            
            _watchIsConnected = YES;
            [self updateWatchIcon];
            [self updateWatch];
            
        } else {
            
            _watchIsConnected = NO;
            [self updateWatchIcon];
            NSString *message = [NSString stringWithFormat:@"Blegh... %@ does NOT support AppMessages :'(", [watch name]];
            NSLog(@"%@", message);
            [self showFatalErrorAlertTitle:@"Watch Error" alertMessage:message];
            
        }
    }];
    
}

- (int)iconIDFromWeatherDescription:(NSString *)weatherDescription {
    
    if ([weatherDescription isEqualToString:kFCIconRain] ||
        [weatherDescription isEqualToString:kFCIconThunderstorm] ||
        [weatherDescription isEqualToString:kFCIconTornado] ||
        [weatherDescription isEqualToString:kFCIconHurricane] ||
        [weatherDescription isEqualToString:kFCIconHail]) {
        return 2;
    } else if ([weatherDescription isEqualToString:kFCIconPartlyCloudyDay] ||
               [weatherDescription isEqualToString:kFCIconPartlyCloudyNight] ||
               [weatherDescription isEqualToString:kFCIconCloudy] ||
               [weatherDescription isEqualToString:kFCIconFog]) {
        return 1;
    } else if ([weatherDescription isEqualToString:kFCIconClearDay] ||
               [weatherDescription isEqualToString:kFCIconClearNight] ||
               [weatherDescription isEqualToString:kFCIconWind]) {
        return 0;
    } else if ([weatherDescription isEqualToString:kFCIconSnow] ||
               [weatherDescription isEqualToString:kFCIconSleet]){
        return 3;
    } else {
        return 1;
    }
    
}

- (void)updateWatch {
    
    // Don't update watch until weather forecast has finished and the watch is connected
    if (_forecastSyncIsFinished && _watchIsConnected) {
        
        _forecastSyncIsFinished = NO;
        
        NSDictionary *update = @{
                                 kKeyWatchIcon       :[NSNumber numberWithUint8:[self iconIDFromWeatherDescription:self.currentConditonsWeatherIcon]],
                                 kKeyWatchTemperature:[NSString stringWithFormat:@"%.1f \u00B0F", [self.currentConditionsTemperature doubleValue]]
                                };
        
        [self.watch appMessagesPushUpdate:update onSent:^(PBWatch *watch, NSDictionary *update, NSError *error) {
            
            NSString *message;
            if (error) {
                
                _watchIsConnected = NO;
                [self updateWatchIcon];
                
                message = [error localizedDescription];
                [self showFatalErrorAlertTitle:@"Watch Error" alertMessage:[error localizedDescription]];
                
            } else {
                
                message = @"Watch update sent";
                
            }
            
            NSLog(@"Watch update: %@", message);
            
        }];
        
    }
}


- (BOOL)handleWatchUpdate:(PBWatch *)watch message:(NSDictionary *)message {
    
    NSLog(@"Message from watch received: %@", message);
    
    if ([message objectForKey:kKeyWatchRequestUpdate]) {
        NSLog(@"Forecast update requested");
        [self refresh];
        return YES;
    }
    
    return NO;
    
}

- (void)updateWatchIcon {
    
    if (_watchIsConnected) {
        self.watchButton.alpha = 1;
    } else {
        self.watchButton.alpha = 0.25;
    }
    
}

#pragma mark - Weather Forecast

- (void)forecastForLocation:(CLLocation *)location {
    
    [self.forecastrManager getForecastForLocation:location time:nil exclusions:nil success:^(id JSON) {
        
//        NSLog(@"JSON response was: %@", JSON);
        NSDictionary *currentConditions = [(NSDictionary *)JSON objectForKey:kFCCurrentlyForecast];
        
        [self updateDisplayWithCurrentConditions:currentConditions];
        
        self.currentConditonsWeatherIcon = [currentConditions objectForKey:kFCIcon];
        self.currentConditionsTemperature = [NSString stringWithFormat:@"%.1f", [[currentConditions objectForKey:kFCTemperature] doubleValue]];

        _forecastSyncIsFinished = YES;
        [self updateWatch];
        
    } failure:^(NSError *error, id response) {
        
        NSLog(@"Error while retrieving forecast: %@", [self.forecastrManager messageForError:error withResponse:response]);
        [self showFatalErrorAlertTitle:@"Forecast Error" alertMessage:[self.forecastrManager messageForError:error withResponse:response]];
        
    }];
    
}

#pragma mark - Display

- (void)setupPhoneDisplay {
    
    self.currentUpdateTimestampLabel.text = @"";
    self.currentLocationLabel.text = @"";
    self.currentTemperatureLabel.text = @"";
    self.currentSummaryLabel.text = @"";
    
}

- (void)updateDisplayWithCurrentConditions:(NSDictionary *)currentConditions {
    
    NSTimeInterval currentTimeInterval = [[currentConditions objectForKey:kFCTime] doubleValue];
    NSDate *currentTimestamp = [NSDate dateWithTimeIntervalSince1970:currentTimeInterval];
    self.currentUpdateTimestampLabel.text = [self formattedDate:currentTimestamp];
    
    NSString *currentTemperature = [NSString stringWithFormat:@"%.1f °F", [[currentConditions objectForKey:kFCTemperature] doubleValue]];
    self.currentTemperatureLabel.text = currentTemperature;
    
    NSString *currentSummary = [NSString stringWithFormat:@"%@", [currentConditions objectForKey:kFCSummary]];
    self.currentSummaryLabel.text = currentSummary;
    
}

- (NSString *)formattedDate:(NSDate *)date {
    
    static NSDateFormatter *dateFormatter;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateStyle:NSDateFormatterShortStyle];
        [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
        
    });
    
    NSString *timeString = [dateFormatter stringFromDate:date];
    
    return timeString;
    
}

#pragma mark - Refresh

- (void)refresh {
    
    // Initialize Pebble watch if it's not connected
    if (!_watchIsConnected) {
        
        [self setTargetWatch:[self.pebbleManager lastConnectedWatch]];
        
        if (self.updateHandler) {
            [self.watch appMessagesRemoveUpdateHandler:self.updateHandler];
            self.updateHandler = nil;
        }
        self.updateHandler = [self.watch appMessagesAddReceiveUpdateHandler:^BOOL(PBWatch *watch, NSDictionary *update) {
            return [self handleWatchUpdate:watch message:update];
        }];
    }
    
    // Initialize location manager
    // location manager will stop once location
    // is found and the delegate is called
    [self.locationManager startUpdatingLocation];
    
}

#pragma mark - IBAction

- (IBAction)refreshTapped:(id)sender {
    
    [self refresh];
    
}

#pragma mark - UIAlert

- (void)showFatalErrorAlertTitle:(NSString *)title alertMessage:(NSString *)alertMessage {
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
                                                    message:alertMessage
                                                   delegate:nil
                                          cancelButtonTitle:@"Ok"
                                          otherButtonTitles:nil];
    [alert show];
    
}

#pragma mark - Segue

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    
    if ([segue.identifier isEqualToString:@"SegueWatchInfo"]) {
        PWWatchInfoViewController *watchInfoViewController = segue.destinationViewController;
        watchInfoViewController.watch = self.watch;
    }
    
}

@end
