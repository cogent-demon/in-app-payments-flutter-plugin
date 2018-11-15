/*
Copyright 2018 Square Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/
package com.squareup.sqip.flutter.internal;

import android.app.Activity;
import android.content.Intent;
import android.support.annotation.NonNull;
import com.google.android.gms.common.api.Status;
import com.google.android.gms.tasks.OnCompleteListener;
import com.google.android.gms.tasks.OnFailureListener;
import com.google.android.gms.tasks.Task;
import com.google.android.gms.wallet.AutoResolveHelper;
import com.google.android.gms.wallet.CardRequirements;
import com.google.android.gms.wallet.IsReadyToPayRequest;
import com.google.android.gms.wallet.PaymentData;
import com.google.android.gms.wallet.PaymentDataRequest;
import com.google.android.gms.wallet.PaymentMethodTokenizationParameters;
import com.google.android.gms.wallet.PaymentsClient;
import com.google.android.gms.wallet.TransactionInfo;
import com.google.android.gms.wallet.Wallet;
import com.google.android.gms.wallet.WalletConstants;
import com.squareup.sqip.flutter.internal.converter.CardConverter;
import com.squareup.sqip.flutter.internal.converter.CardDetailsConverter;
import com.squareup.sqip.Callback;
import com.squareup.sqip.GooglePay;
import com.squareup.sqip.GooglePayNonceResult;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;
import java.util.Arrays;
import java.util.List;

final public class GooglePayModule {

  // Android only flutter plugin errors and messages
  private static final String FL_GOOGLE_PAY_RESULT_ERROR = "fl_google_pay_result_error";
  private static final String FL_GOOGLE_PAY_UNKNOWN_ERROR = "fl_google_pay_unknown_error";
  private static final String FL_MESSAGE_GOOGLE_PAY_RESULT_ERROR = "Failed to launch google pay, please make sure you configured google pay correctly.";
  private static final String FL_MESSAGE_GOOGLE_PAY_UNKNOWN_ERROR = "Unknown google pay activity result status.";

  private static final int LOAD_PAYMENT_DATA_REQUEST_CODE = 1;
  private static final List<Integer> CARD_NETWORKS = Arrays.asList(
      WalletConstants.CARD_NETWORK_AMEX,
      WalletConstants.CARD_NETWORK_DISCOVER,
      WalletConstants.CARD_NETWORK_JCB,
      WalletConstants.CARD_NETWORK_VISA,
      WalletConstants.CARD_NETWORK_MASTERCARD,
      WalletConstants.CARD_NETWORK_OTHER
  );

  private final Activity currentActivity;
  private final PaymentsClient googlePayClients;
  private final CardDetailsConverter cardDetailsConverter;
  private final String merchantId;

  public GooglePayModule(PluginRegistry.Registrar registrar, final MethodChannel channel, String environment, String merchantId) {
    currentActivity = registrar.activity();
    cardDetailsConverter = new CardDetailsConverter(new CardConverter());
    this.merchantId = merchantId;
    int env = WalletConstants.ENVIRONMENT_TEST;
    if (environment.equals("PROD")) {
      env = WalletConstants.ENVIRONMENT_PRODUCTION;
    }

    googlePayClients = Wallet.getPaymentsClient(
        currentActivity,
        (new Wallet.WalletOptions.Builder())
            .setEnvironment(env)
            .build()
    );

    // Register callback when google pay activity is dismissed
    registrar.addActivityResultListener(new PluginRegistry.ActivityResultListener() {
      @Override public boolean onActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode == LOAD_PAYMENT_DATA_REQUEST_CODE) {
          switch (resultCode) {
            case Activity.RESULT_OK:
              PaymentData paymentData = PaymentData.getFromIntent(data);
              String googlePayToken = paymentData.getPaymentMethodToken().getToken();
              GooglePay.requestGooglePayNonce(googlePayToken).enqueue(
                  new Callback<GooglePayNonceResult>() {
                    @Override public void onResult(GooglePayNonceResult googlePayNonceResult) {
                      if (googlePayNonceResult.isSuccess()) {
                        channel.invokeMethod("onGooglePayNonceRequestSuccess", cardDetailsConverter.toMapObject(googlePayNonceResult.getSuccessValue()));
                      } else if (googlePayNonceResult.isError()) {
                        GooglePayNonceResult.Error error = ((GooglePayNonceResult.Error) googlePayNonceResult);
                        channel.invokeMethod("onGooglePayNonceRequestFailure", ErrorHandlerUtils.getCallbackErrorObject(error.getCode().name(), error.getMessage(), error.getDebugCode(), error.getDebugMessage()));
                      }
                    }
                  });
              break;
            case Activity.RESULT_CANCELED:
              channel.invokeMethod("onGooglePayCanceled", null);
              break;
            case AutoResolveHelper.RESULT_ERROR:
              Status status = AutoResolveHelper.getStatusFromIntent(data);
              channel.invokeMethod("onGooglePayNonceRequestFailure",
                  ErrorHandlerUtils.getCallbackErrorObject(ErrorHandlerUtils.USAGE_ERROR, ErrorHandlerUtils.getPluginErrorMessage(FL_GOOGLE_PAY_RESULT_ERROR), FL_GOOGLE_PAY_RESULT_ERROR, FL_MESSAGE_GOOGLE_PAY_RESULT_ERROR));
              break;
            default:
              channel.invokeMethod("onGooglePayNonceRequestFailure",
                  ErrorHandlerUtils.getCallbackErrorObject(ErrorHandlerUtils.USAGE_ERROR, ErrorHandlerUtils.getPluginErrorMessage(FL_GOOGLE_PAY_UNKNOWN_ERROR), FL_GOOGLE_PAY_UNKNOWN_ERROR, FL_MESSAGE_GOOGLE_PAY_UNKNOWN_ERROR));
          }
        }
        return false;
      }
    });
  }

  public void canUserGooglePay(final MethodChannel.Result result) {
    IsReadyToPayRequest isReadyToPayRequest = GooglePay.createIsReadyToPayRequest();
    googlePayClients.isReadyToPay(isReadyToPayRequest).addOnCompleteListener(new OnCompleteListener<Boolean>() {
      @Override
      public void onComplete(@NonNull Task<Boolean> task) {
        result.success(task.isSuccessful());
      }
    });
  }

  public void requestGooglePayNonce(MethodChannel.Result result, String price, String currencyCode) {
    AutoResolveHelper.resolveTask(
        googlePayClients.loadPaymentData(_createPaymentChargeRequest(merchantId, price, currencyCode)),
        currentActivity,
        LOAD_PAYMENT_DATA_REQUEST_CODE);
    result.success(null);
  }

  private PaymentDataRequest _createPaymentChargeRequest(String merchantId, String price, String currencyCode) {
    // TODO: Add support for google pay configuration
    PaymentDataRequest.Builder request = PaymentDataRequest
        .newBuilder().setTransactionInfo(
            TransactionInfo.newBuilder()
                .setTotalPriceStatus(
                    WalletConstants.TOTAL_PRICE_STATUS_FINAL)
                .setTotalPrice(price)
                .setCurrencyCode(currencyCode)
                .build()
        ).addAllowedPaymentMethod(WalletConstants.PAYMENT_METHOD_CARD)
        .setCardRequirements(
            CardRequirements.newBuilder()
                .addAllowedCardNetworks(CARD_NETWORKS)
                .build()
        );
    PaymentMethodTokenizationParameters params = PaymentMethodTokenizationParameters
        .newBuilder()
        .setPaymentMethodTokenizationType(
            WalletConstants.PAYMENT_METHOD_TOKENIZATION_TYPE_PAYMENT_GATEWAY)
        .addParameter("gateway","square")
        .addParameter("gatewayMerchantId", merchantId)
        .build();
    request.setPaymentMethodTokenizationParameters(params);
    return request.build();
  }
}
