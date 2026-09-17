import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pos_tanzania_mobile/services/api_service.dart';

/// The app told sellers their network was down while the phone plainly had
/// data. The cause was one classification: every exception caught in
/// ApiService -- including a JSON parse failure on a 502 HTML page -- was
/// announced as "server unreachable". These pin the distinction.
void main() {
  group('what counts as the network failing', () {
    test('real transport failures are recognised', () {
      expect(
        ApiService.isTransportException(
          const SocketException('Failed host lookup: leruma.co.tz'),
        ),
        isTrue,
      );
      expect(ApiService.isTransportException(TimeoutException('Future not completed', const Duration(seconds: 30))), isTrue);
      expect(
        ApiService.isTransportException(
          http.ClientException('Connection closed before full header was received'),
        ),
        isTrue,
      );
    });

    test('a server answering badly is NOT the network', () {
      // What a 502 HTML page or a PHP warning produces once json.decode sees it.
      expect(
        ApiService.isTransportException(
          const FormatException('Unexpected character (at character 1)'),
        ),
        isFalse,
      );
      // A model built from an unexpected payload shape.
      expect(ApiService.isTransportException(TypeError()), isFalse);
      // Secure storage refusing on a locked device.
      expect(ApiService.isTransportException(Exception('PlatformException')), isFalse);
    });
  });
}
