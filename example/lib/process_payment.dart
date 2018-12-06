import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:square_in_app_payments/models.dart';
import 'package:square_in_app_payments/in_app_payments.dart';
import 'package:http/http.dart' as http;
import 'buy_screen.dart';
import 'util.dart';

class MyNotification extends Notification {
  final bool visible;

  const MyNotification({this.visible});
}

class ProcessPayment {

  bool paymentInitialized = false;
  bool applePayEnabled = false;
  bool googlePayEnabled = false;
  BuyScreenState buyScreenState;

  ProcessPayment(this.buyScreenState) {
    initSquarePayment();
  }

  Future<void> initSquarePayment() async {
    var canUseApplePay = false;
    var canUseGooglePay = false;
    if(Platform.isAndroid) {
      canUseGooglePay = await InAppPayments.canUseGooglePay;
    } else if (Platform.isIOS) {
      canUseApplePay = await InAppPayments.canUseApplePay;
    }

    paymentInitialized = true;
    applePayEnabled = canUseApplePay;
    googlePayEnabled = canUseGooglePay;
  }

  Future<void> _checkout(CardDetails result) async {
    var url = "https://26brjd4ue9.execute-api.us-east-1.amazonaws.com/default/chargeForCookie";
    var body = jsonEncode({"nonce": result.nonce});
    await http.post(url, body: body, headers: {
        "Accept": "application/json",
        "content-type": "application/json"
      })
      .then((response) {
        var body = json.decode(response.body);
        if (response.statusCode == 200) {
          InAppPayments.completeCardEntry(onCardEntryComplete: onCardEntryComplete);
        } else {
          InAppPayments.showCardNonceProcessingError(body["errorMessage"]);
        }
    });
  }

  void onCardEntryComplete() {
    Navigator.pop(buyScreenState.context, true);
  }

  void onCardEntryCardNonceRequestSuccess(CardDetails result) async {
    await _checkout(result);
  }

  Future<void> onStartCardEntryFlow() async {
    try {
      await InAppPayments.startCardEntryFlow(onCardNonceRequestSuccess: onCardEntryCardNonceRequestSuccess, onCardEntryCancel: onCardEntryCancel);
    } on PlatformException {
      showError(buyScreenState.context, "Failed to start card entry");
    }
  }

  void onCardEntryCancel() async {
    buyScreenState.setVisible();
  }

  void onStartGooglePay() async {
    try {
      await InAppPayments.requestGooglePayNonce(
        priceStatus: 1,
        price: '100',
        currencyCode: 'USD',
        onGooglePayNonceRequestSuccess: onGooglePayNonceRequestSuccess,
        onGooglePayNonceRequestFailure: onGooglePayNonceRequestFailure,
        onGooglePayCanceled: onGooglePayCancel);
    } on PlatformException catch(ex) {
        showError(buyScreenState.context, 'Failed to start GooglePay.\n ${ex.toString()}');
    }
  }


  void onGooglePayNonceRequestSuccess(CardDetails result) async {
      await _checkout(result);
  }

  void onGooglePayCancel() {
    buyScreenState.setVisible();
  }

  void onGooglePayNonceRequestFailure(ErrorInfo errorInfo) {
    showError(buyScreenState.context, 'GooglePay failed.\n ${errorInfo.toString()}');
  }

  void onStartApplePay() async {
    try {
      await InAppPayments.requestApplePayNonce(
        price: '100', 
        summaryLabel: 'My Checkout',
        countryCode: 'US', 
        currencyCode: 'USD', 
        onApplePayNonceRequestSuccess: onApplePayNonceRequestSuccess,
        onApplePayNonceRequestFailure: onApplePayNonceRequestFailure,
        onApplePayComplete: onApplePayComplete);
    } on PlatformException catch(ex) {
      showError(buyScreenState.context, 'Failed to start ApplePay.\n ${ex.toString()}');
    }
  }

  void onApplePayNonceRequestSuccess(CardDetails result) async {
    await _checkout(result);
  } 

  void onApplePayNonceRequestFailure(ErrorInfo errorInfo) async {
    await InAppPayments.completeApplePayAuthorization(isSuccess: false);
  }

  void onApplePayComplete() {
    buyScreenState.setVisible();
  }
}