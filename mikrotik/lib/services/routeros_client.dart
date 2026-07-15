import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Помилка протоколу RouterOS API (!trap / !fatal / обрив з'єднання).
class RouterOSException implements Exception {
  final String message;
  RouterOSException(this.message);

  @override
  String toString() => message;
}

/// Клієнт бінарного протоколу MikroTik RouterOS API (api / api-ssl).
///
/// Підтримує RouterOS 5.xx – 7.xx:
///  - новий логін (>= 6.43): /login з =name= та =password=
///  - старий логін (< 6.43): challenge-response через MD5
///
/// Порти за замовчуванням: api — 8728, api-ssl — 8729.
class RouterOSClient {
  Socket? _socket;
  final List<int> _rx = [];
  Completer<void>? _dataArrived;
  bool _closed = false;
  Object? _socketError;
  Future<dynamic> _lock = Future.value();

  bool get isConnected => _socket != null && !_closed;

  Future<void> connect(
    String host,
    int port, {
    bool useSsl = false,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (useSsl) {
      // Роутери зазвичай мають самопідписаний сертифікат.
      _socket = await SecureSocket.connect(
        host,
        port,
        timeout: timeout,
        onBadCertificate: (_) => true,
      );
    } else {
      _socket = await Socket.connect(host, port, timeout: timeout);
    }
    _socket!.listen(
      (data) {
        _rx.addAll(data);
        _wake();
      },
      onError: (Object e) {
        _socketError = e;
        _closed = true;
        _wake();
      },
      onDone: () {
        _closed = true;
        _wake();
      },
    );
  }

  Future<void> login(String username, String password) async {
    final res = await talk(['/login', '=name=$username', '=password=$password']);
    // RouterOS < 6.43 ігнорує пароль і повертає =ret= (challenge).
    final ret = res.isNotEmpty ? res.last['ret'] : null;
    if (ret != null && ret.isNotEmpty) {
      final challenge = _hexToBytes(ret);
      final digest =
          md5.convert(<int>[0, ...utf8.encode(password), ...challenge]).bytes;
      await talk([
        '/login',
        '=name=$username',
        '=response=00${_bytesToHex(digest)}',
      ]);
    }
  }

  /// Надсилає команду та повертає всі !re-відповіді як список мап атрибутів.
  /// Кидає [RouterOSException] при !trap або !fatal.
  Future<List<Map<String, String>>> talk(List<String> words) {
    final result = _lock.then((_) => _talkInner(words));
    _lock = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Future<List<Map<String, String>>> _talkInner(List<String> words) async {
    if (!isConnected) {
      throw RouterOSException('Немає з\'єднання з роутером');
    }
    _writeSentence(words);
    final results = <Map<String, String>>[];
    String? trapMessage;
    while (true) {
      final sentence = await _readSentence();
      if (sentence.isEmpty) continue;
      final reply = sentence.first;
      final attrs = <String, String>{};
      for (final w in sentence.skip(1)) {
        if (w.startsWith('=')) {
          final idx = w.indexOf('=', 1);
          if (idx > 0) {
            attrs[w.substring(1, idx)] = w.substring(idx + 1);
          } else {
            attrs[w.substring(1)] = '';
          }
        }
      }
      switch (reply) {
        case '!re':
          results.add(attrs);
        case '!trap':
          trapMessage = attrs['message'] ?? sentence.skip(1).join(' ');
        case '!fatal':
          close();
          throw RouterOSException(sentence.skip(1).join(' '));
        case '!done':
          if (trapMessage != null) throw RouterOSException(trapMessage);
          // !done може нести =ret= (наприклад, challenge при логіні).
          if (attrs.isNotEmpty) results.add(attrs);
          return results;
      }
    }
  }

  void close() {
    _closed = true;
    _socket?.destroy();
    _socket = null;
    _wake();
  }

  // ---- низькорівневий протокол ----

  void _writeSentence(List<String> words) {
    final bb = BytesBuilder();
    for (final w in words) {
      final bytes = utf8.encode(w);
      bb.add(_encodeLength(bytes.length));
      bb.add(bytes);
    }
    bb.addByte(0); // порожнє слово — кінець речення
    _socket!.add(bb.toBytes());
  }

  Future<List<String>> _readSentence() async {
    final words = <String>[];
    while (true) {
      final len = await _readLength();
      if (len == 0) return words;
      final data = await _readBytes(len);
      words.add(utf8.decode(data, allowMalformed: true));
    }
  }

  Future<int> _readLength() async {
    final b0 = (await _readBytes(1))[0];
    if ((b0 & 0x80) == 0) return b0;
    if ((b0 & 0xC0) == 0x80) {
      final b = await _readBytes(1);
      return ((b0 & 0x3F) << 8) | b[0];
    }
    if ((b0 & 0xE0) == 0xC0) {
      final b = await _readBytes(2);
      return ((b0 & 0x1F) << 16) | (b[0] << 8) | b[1];
    }
    if ((b0 & 0xF0) == 0xE0) {
      final b = await _readBytes(3);
      return ((b0 & 0x0F) << 24) | (b[0] << 16) | (b[1] << 8) | b[2];
    }
    final b = await _readBytes(4);
    return (b[0] << 24) | (b[1] << 16) | (b[2] << 8) | b[3];
  }

  List<int> _encodeLength(int len) {
    if (len < 0x80) return [len];
    if (len < 0x4000) return [(len >> 8) | 0x80, len & 0xFF];
    if (len < 0x200000) {
      return [(len >> 16) | 0xC0, (len >> 8) & 0xFF, len & 0xFF];
    }
    if (len < 0x10000000) {
      return [
        (len >> 24) | 0xE0,
        (len >> 16) & 0xFF,
        (len >> 8) & 0xFF,
        len & 0xFF,
      ];
    }
    return [
      0xF0,
      (len >> 24) & 0xFF,
      (len >> 16) & 0xFF,
      (len >> 8) & 0xFF,
      len & 0xFF,
    ];
  }

  Future<Uint8List> _readBytes(int n) async {
    while (_rx.length < n) {
      if (_closed) {
        throw RouterOSException(
            _socketError?.toString() ?? 'З\'єднання розірвано');
      }
      _dataArrived = Completer<void>();
      await _dataArrived!.future;
    }
    final out = Uint8List.fromList(_rx.sublist(0, n));
    _rx.removeRange(0, n);
    return out;
  }

  void _wake() {
    final c = _dataArrived;
    if (c != null && !c.isCompleted) c.complete();
  }

  static List<int> _hexToBytes(String hex) {
    final out = <int>[];
    for (var i = 0; i + 1 < hex.length; i += 2) {
      out.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return out;
  }

  static String _bytesToHex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
