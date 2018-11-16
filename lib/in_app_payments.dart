import 'dart:async';

import 'package:flutter/services.dart';
import 'package:built_value/standard_json_plugin.dart';
import 'package:meta/meta.dart';
import 'models.dart';
import 'serializers.dart';

typedef CardEntryDidCancelCallback = void Function();
typedef CardEntryCompleteCallback = void Function();
typedef CardEntryCardNonceRequestSuccessCallback = void Function(CardDetails result);

typedef GooglePayNonceRequestSuccessCallback = void Function(CardDetails result);
typedef GooglePayNonceRequestFailureCallback = void Function(ErrorInfo errorInfo);
typedef GooglePayCancelCallback = void Function();

typedef ApplePayNonceRequestSuccessCallback = void Function(CardDetails result);
typedef ApplePayNonceRequestFailureCallback = void Function(ErrorInfo errorInfo);
typedef ApplePayCompleteCallback = void Function();

// ignore: avoid_classes_with_only_static_members
class InAppPayments {
  static final MethodChannel _channel =
      const MethodChannel('square_in_app_payments')..setMethodCallHandler(_nativeCallHandler);

  static final _standardSerializers = (serializers.toBuilder()..addPlugin(StandardJsonPlugin())).build();

  static CardEntryDidCancelCallback _cardEntryDidCancelCallback;
  static CardEntryCardNonceRequestSuccessCallback _cardEntryCardNonceRequestSuccessCallback;
  static CardEntryCompleteCallback _cardEntryCompleteCallback;

  static GooglePayNonceRequestSuccessCallback _googlePayNonceRequestSuccessCallback;
  static GooglePayNonceRequestFailureCallback _googlePayNonceRequestFailureCallback;
  static GooglePayCancelCallback _googlePayCancelCallback;

  static ApplePayNonceRequestSuccessCallback _applePayNonceRequestSuccessCallback;
  static ApplePayNonceRequestFailureCallback _applePayNonceRequestFailureCallback;
  static ApplePayCompleteCallback _applePayCompleteCallback;

  static Future<dynamic> _nativeCallHandler(MethodCall call) async {
    try {
      switch (call.method) {
        case 'cardEntryDidCancel':
          if (_cardEntryDidCancelCallback != null) {
            _cardEntryDidCancelCallback();
          }
          break;
        case 'cardEntryDidObtainCardDetails':
          if (_cardEntryCardNonceRequestSuccessCallback != null) {
            var result = _standardSerializers.deserializeWith(CardDetails.serializer, call.arguments);
            _cardEntryCardNonceRequestSuccessCallback(result);
          }
          break;
        case 'cardEntryComplete':
          if (_cardEntryCompleteCallback != null) {
            _cardEntryCompleteCallback();
          }
          break;
        case 'onGooglePayCanceled':
          if (_googlePayCancelCallback != null) {
            _googlePayCancelCallback();
          }
          break;
        case 'onGooglePayNonceRequestSuccess':
          if (_googlePayNonceRequestSuccessCallback != null) {
            var result = _standardSerializers.deserializeWith(CardDetails.serializer, call.arguments);
            _googlePayNonceRequestSuccessCallback(result);
          }
          break;
        case 'onGooglePayNonceRequestFailure':
          if (_googlePayNonceRequestFailureCallback != null) {
            var errorInfo = _standardSerializers.deserializeWith(ErrorInfo.serializer, call.arguments);
            _googlePayNonceRequestFailureCallback(errorInfo);
          }
          break;
        case 'onApplePayNonceRequestSuccess':
          if (_applePayNonceRequestSuccessCallback != null) {
            var result = _standardSerializers.deserializeWith(CardDetails.serializer, call.arguments);
            _applePayNonceRequestSuccessCallback(result);
          }
          break;
        case 'onApplePayNonceRequestFailure':
          if (_applePayNonceRequestFailureCallback != null) {
            var errorInfo = _standardSerializers.deserializeWith(ErrorInfo.serializer, call.arguments);
            _applePayNonceRequestFailureCallback(errorInfo);
          }
          break;
        case 'onApplePayComplete':
          if (_applePayCompleteCallback != null) {
            _applePayCompleteCallback();
          }
          break;
        default:
          throw Exception('unknown method called from native');
      }
    } on Exception catch (ex) {
      // TOOD: report error
      print(ex);
    }
    return false;
  }

  static Future setSquareApplicationId(String applicationId) async {
    assert(applicationId != null && applicationId.isNotEmpty, 'application should not be null or empty.');
    try {
      var params = <String, dynamic> {
        'applicationId': applicationId,
      };
      await _channel.invokeMethod('setApplicationId', params);
    } on PlatformException catch (ex) {
      throw InAppPaymentException(ex.code, ex.message, ex.details[InAppPaymentException.debugCodeKey], ex.details[InAppPaymentException.debugMessageKey]);
    }
  }

  static Future startCardEntryFlow({CardEntryCardNonceRequestSuccessCallback onCardNonceRequestSuccess, CardEntryDidCancelCallback onCardEntryCancel}) async {
    _cardEntryDidCancelCallback = onCardEntryCancel;
    _cardEntryCardNonceRequestSuccessCallback = onCardNonceRequestSuccess;
    try {
      await _channel.invokeMethod('startCardEntryFlow');
    } on PlatformException catch (ex) {
      throw InAppPaymentException(ex.code, ex.message, ex.details[InAppPaymentException.debugCodeKey], ex.details[InAppPaymentException.debugMessageKey]);
    }
  }

  static Future completeCardEntry({CardEntryCompleteCallback onCardEntryComplete}) async {
    _cardEntryCompleteCallback = onCardEntryComplete;
    try {
      await _channel.invokeMethod('completeCardEntry');
    } on PlatformException catch (ex) {
      throw InAppPaymentException(ex.code, ex.message, ex.details[InAppPaymentException.debugCodeKey], ex.details[InAppPaymentException.debugMessageKey]);
    }
  }

  static Future showCardNonceProcessingError(String errorMessage) async {
    try {
      var params = <String, dynamic> {
        'errorMessage': errorMessage,
      };
      await _channel.invokeMethod('showCardNonceProcessingError', params);
    } on PlatformException catch (ex) {
      throw InAppPaymentException(ex.code, ex.message, ex.details[InAppPaymentException.debugCodeKey], ex.details[InAppPaymentException.debugMessageKey]);
    }
  }

  static Future initializeGooglePay(String merchantId, GooglePayEnvironment environment) async {
    assert(environment != null, 'environment should not be null.');
    assert(merchantId != null && merchantId.isNotEmpty, 'merchantId should not be null or empty.');
    try {
      var params = <String, dynamic> {
        'environment': serializers.serializeWith(GooglePayEnvironment.serializer, environment),
        'merchantId': merchantId,
      };
      await _channel.invokeMethod('initializeGooglePay', params);
    } on PlatformException catch (ex) {
      throw InAppPaymentException(ex.code, ex.message, ex.details[InAppPaymentException.debugCodeKey], ex.details[InAppPaymentException.debugMessageKey]);
    }
  }

  static Future<bool> get canUseGooglePay async {
    try {
      return await _channel.invokeMethod('canUseGooglePay');
    } on PlatformException catch (ex) {
      throw InAppPaymentException(ex.code, ex.message, ex.details[InAppPaymentException.debugCodeKey], ex.details[InAppPaymentException.debugMessageKey]);
    }
  }

  static Future requestGooglePayNonce({
    @required String price,
    @required String currencyCode,
    GooglePayNonceRequestSuccessCallback onGooglePayNonceRequestSuccess,
    GooglePayNonceRequestFailureCallback onGooglePayNonceRequestFailure,
    GooglePayCancelCallback onGooglePayCanceled
    }) async {
    assert(price != null && price.isNotEmpty, 'price should not be null or empty.');
    assert(currencyCode != null && currencyCode.isNotEmpty, 'currencyCode should not be null or empty.');

    _googlePayNonceRequestSuccessCallback = onGooglePayNonceRequestSuccess;
    _googlePayNonceRequestFailureCallback = onGooglePayNonceRequestFailure;
    _googlePayCancelCallback = onGooglePayCanceled;

    try {
      var params = <String, dynamic> {
        'price': price,
        'currencyCode': currencyCode,
      };
      await _channel.invokeMethod('requestGooglePayNonce', params);
    } on PlatformException catch (ex) {
      throw InAppPaymentException(ex.code, ex.message, ex.details[InAppPaymentException.debugCodeKey], ex.details[InAppPaymentException.debugMessageKey]);
    }
  }

  static Future initializeApplePay(String applePayMerchantId) async {
    assert(applePayMerchantId != null && applePayMerchantId.isNotEmpty, 'applePayMerchantId should not be null or empty.');
    try {
      var params = <String, dynamic> {
        'merchantId': applePayMerchantId,
    };
      await _channel.invokeMethod('initializeApplePay', params);
    } on PlatformException catch (ex) {
      throw InAppPaymentException(ex.code, ex.message, ex.details[InAppPaymentException.debugCodeKey], ex.details[InAppPaymentException.debugMessageKey]);
    }
  }

  static Future<bool> get canUseApplePay async {
    try {
      return await _channel.invokeMethod('canUseApplePay');
    } on PlatformException catch (ex) {
      throw InAppPaymentException(ex.code, ex.message, ex.details[InAppPaymentException.debugCodeKey], ex.details[InAppPaymentException.debugMessageKey]);
    }
  }

  static Future requestApplePayNonce({
    @required String price,
    @required String summaryLabel,
    @required String countryCode,
    @required String currencyCode,
    ApplePayNonceRequestSuccessCallback onApplePayNonceRequestSuccess,
    ApplePayNonceRequestFailureCallback onApplePayNonceRequestFailure,
    ApplePayCompleteCallback onApplePayComplete
    }) async {
    assert(summaryLabel != null && summaryLabel.isNotEmpty, 'summaryLabel should not be null or empty.');
    assert(price != null && price.isNotEmpty, 'price should not be null or empty.');
    assert(countryCode != null && countryCode.isNotEmpty, 'countryCode should not be null or empty.');
    assert(currencyCode != null && currencyCode.isNotEmpty, 'currencyCode should not be null or empty.');

    _applePayNonceRequestSuccessCallback = onApplePayNonceRequestSuccess;
    _applePayNonceRequestFailureCallback = onApplePayNonceRequestFailure;
    _applePayCompleteCallback = onApplePayComplete;

    try {
      var params = <String, dynamic> {
        'price': price,
        'summaryLabel': summaryLabel,
        'countryCode': countryCode,
        'currencyCode': currencyCode,
      };
      await _channel.invokeMethod('requestApplePayNonce', params);
    } on PlatformException catch (ex) {
      throw InAppPaymentException(ex.code, ex.message, ex.details[InAppPaymentException.debugCodeKey], ex.details[InAppPaymentException.debugMessageKey]);
    }
  }

  static Future completeApplePayAuthorization({@required bool isSuccess, String errorMessage = ''}) async {
    try {
      var params = <String, dynamic> {
        'isSuccess': isSuccess,
        'errorMessage': errorMessage,
      };
      await _channel.invokeMethod('completeApplePayAuthorization', params);
    } on PlatformException catch (ex) {
      throw InAppPaymentException(ex.code, ex.message, ex.details[InAppPaymentException.debugCodeKey], ex.details[InAppPaymentException.debugMessageKey]);
    }
  }

  static Future setIOSCardEntryTheme(IOSTheme themeConfiguration) async {
    try {
      var params = <String, dynamic> {
        'themeConfiguration': _standardSerializers.serializeWith(IOSTheme.serializer, themeConfiguration),
      };
      await _channel.invokeMethod('setFormTheme', params);
    } on PlatformException catch (ex) {
      throw InAppPaymentException(ex.code, ex.message, ex.details[InAppPaymentException.debugCodeKey], ex.details[InAppPaymentException.debugMessageKey]);
    }
  }
}

class InAppPaymentException implements Exception {
  static const String debugCodeKey = 'debugCode';
  static const String debugMessageKey = 'debugMessage';

  static final _standardSerializers = (serializers.toBuilder()..addPlugin(StandardJsonPlugin())).build();

  final String _code;

  final String message;

  final String debugCode;

  final String debugMessage;

  ErrorCode get code => _standardSerializers.deserializeWith(ErrorCode.serializer, _code);

  InAppPaymentException(
    this._code,
    this.message,
    this.debugCode,
    this.debugMessage,
  ) : assert(_code != null), assert(debugCode != null);

  @override
  String toString() => 'PlatformException($code, $message, $debugCode, $debugMessage)';
}
