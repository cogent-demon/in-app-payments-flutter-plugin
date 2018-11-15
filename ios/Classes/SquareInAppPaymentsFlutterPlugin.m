#import "SquareInAppPaymentsFlutterPlugin.h"
#import "FSQIPCardEntry.h"
#import "FSQIPApplePay.h"
#import "FSQIPErrorUtilities.h"

@interface SquareInAppPaymentsFlutterPlugin()

@property (strong, readwrite) FSQIPCardEntry* cardEntryModule;
@property (strong, readwrite) FSQIPApplePay* applePayModule;
@end

FlutterMethodChannel* _channel;

@implementation SquareInAppPaymentsFlutterPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:@"square_in_app_payments"
            binaryMessenger:[registrar messenger]];
    _channel = channel;
    SquareInAppPaymentsFlutterPlugin* instance = [[SquareInAppPaymentsFlutterPlugin alloc] init];
    [registrar addMethodCallDelegate:instance channel:channel];
}

- (instancetype)init
{
    self = [super init];
    if (!self) {
        return nil;
    }
    self.cardEntryModule = [[FSQIPCardEntry alloc] init];
    [self.cardEntryModule initWithMethodChannel:_channel];
    return self;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([@"getPlatformVersion" isEqualToString:call.method]) {
        result([@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
    } else if ([@"setApplicationId" isEqualToString:call.method]) {
        NSString* applicationId = call.arguments[@"applicationId"];
        SQIPInAppPaymentsSDK.squareApplicationID = applicationId;
        result(nil);
    } else if ([@"startCardEntryFlow" isEqualToString:call.method]) {
        [self.cardEntryModule startCardEntryFlow:result];
    } else if ([@"completeCardEntry" isEqualToString:call.method]) {
        [self.cardEntryModule completeCardEntry:result];
    } else if ([@"showCardNonceProcessingError" isEqualToString:call.method]) {
        [self.cardEntryModule showCardNonceProcessingError:result errorMessage:call.arguments[@"errorMessage"]];
    } else if ([@"initializeApplePay" isEqualToString:call.method]) {
        self.applePayModule = [[FSQIPApplePay alloc] init];
        [self.applePayModule initWithMethodChannel:_channel];
        [self.applePayModule initializeApplePay:result merchantId:call.arguments[@"merchantId"]];
    } else if ([@"canUseApplePay" isEqualToString:call.method]) {
        if (!self.applePayModule) {
            result([FlutterError errorWithCode:FlutterMobileCommerceUsageError
                                       message:[FSQIPErrorUtilities pluginErrorMessageFromErrorCode:@"fl_mcomm_apple_pay_not_initialize"]
                                       details:[FSQIPErrorUtilities debugErrorObject:@"fl_mcomm_apple_pay_not_initialize" debugMessage:@"You must initialize apple pay before use it."]]);
            return;
        }
        [self.applePayModule canUseApplePay:result];
    } else if ([@"requestApplePayNonce" isEqualToString:call.method]) {
        if (!self.applePayModule) {
            result([FlutterError errorWithCode:FlutterMobileCommerceUsageError
                                       message:[FSQIPErrorUtilities pluginErrorMessageFromErrorCode:@"fl_mcomm_apple_pay_not_initialize"]
                                       details:[FSQIPErrorUtilities debugErrorObject:@"fl_mcomm_apple_pay_not_initialize" debugMessage:@"You must initialize apple pay before use it."]]);
            return;
        }
        NSString *countryCode = call.arguments[@"countryCode"];
        NSString *currencyCode = call.arguments[@"currencyCode"];
        NSString *summaryLabel = call.arguments[@"summaryLabel"];
        NSString *price = call.arguments[@"price"];
        [self.applePayModule requestApplePayNonce:result
                                      countryCode:countryCode
                                     currencyCode:currencyCode
                                     summaryLabel:summaryLabel
                                            price:price];
    } else if ([@"completeApplePayAuthorization" isEqualToString:call.method]) {
        if (!self.applePayModule) {
            result([FlutterError errorWithCode:FlutterMobileCommerceUsageError
                                       message:[FSQIPErrorUtilities pluginErrorMessageFromErrorCode:@"fl_mcomm_apple_pay_not_initialize"]
                                       details:[FSQIPErrorUtilities debugErrorObject:@"fl_mcomm_apple_pay_not_initialize" debugMessage:@"You must initialize apple pay before use it."]]);
            return;
        }
        Boolean isSuccess = [call.arguments[@"isSuccess"] boolValue];
        NSString *errorMessage = call.arguments[@"errorMessage"];
        [self.applePayModule completeApplePayAuthorization:result isSuccess:isSuccess errorMessage:errorMessage];
    } else {
        result(FlutterMethodNotImplemented);
    }
}

@end
