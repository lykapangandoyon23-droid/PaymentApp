import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/stripe_config.dart';

class StripeServices {
  static const Map<String, String> _testTokens = {
    '4242424242424242': 'tok_visa',
    '8989898989898989': 'tok_visa',
    '1011101110111011': 'tok_visa_debit',
    '1213121312131213': 'tok_mastercard',
    '1415141514151415': 'tok_mastercard_debit',
    '1617161716171617': 'tok_chargeDeclined',
    '1819181918191819': 'tok_chargeDeclineInsufficientFunds',
    '4000000000000002': 'tok_chargeDeclined',
  };


  static Future<Map<String, dynamic>> processPayment({
    required double amount,
    required String cardNumber,
    required String expMonth,
    required String expYear,
    required String cvc,
  }) async {
    final amountInCentavos = (amount * 100).round().toString();
    final cleanCard = cardNumber.replaceAll(' ', '');
    final token = _testTokens[cleanCard];

    if (token == null) {
      return <String, dynamic>{
        'success': false, //
        'error': 'Unknown test card. Use 4242... or the ones listed.'
      };
    }

    try {
      final response = await http.post(
          Uri.parse('${StripeConfig.apiUrl}/payment_intents'),
          headers: <String, String>{
            'Authorization': 'Bearer ${StripeConfig.secretKey}',
            'Content-Type': 'application/x-www-form-urlencoded', // Fixed Content_Type
          },
          body: <String, String>{
            'amount': amountInCentavos,
            'currency': 'php',
            'payment_method_types[]': 'card',
            // FIXED THE TYPO HERE: Changed payment_method_day to payment_method_data
            'payment_method_data[type]': 'card',
            'payment_method_data[card][token]': token,
            'confirm': 'true',
          });

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      // Fixed typo: succeeded (Stripe returns 'succeeded' not 'succeded')
      if (response.statusCode == 200 && (data['status'] == 'succeeded' || data['status'] == 'requires_capture')) {
        final paidAmount = (data['amount'] as num) / 100;
        return <String, dynamic>{
          'success': true,
          'id': data['id'].toString(),
          'amount': paidAmount,
          'status': data['status'].toString(),
        };
      } else {
        final errorMsg = data['error'] is Map
            ? (data['error'] as Map)['message']?.toString() ?? 'Payment failed'
            : 'Payment failed';
        return <String, dynamic>{
          'success': false,
          'error': errorMsg,
        };
      }
    } catch (e) {
      return <String, dynamic>{
        'success': false,
        'error': e.toString(),
      };
    }
  }
}