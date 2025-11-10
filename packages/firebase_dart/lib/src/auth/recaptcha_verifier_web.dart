import 'dart:async';
import 'dart:js_interop';
import 'dart:math';

import 'package:js/js.dart' as js;
import 'package:web/web.dart' as web;

import 'auth.dart';
import 'grecaptcha.dart';
import 'impl/auth.dart';

// Helper function to set JS properties using dart:js_interop
@JS('Object.assign')
external void _jsObjectAssign(JSObject target, JSObject source);

void _setJSProperty(JSObject obj, String name, JSAny value) {
  // Use JS interop to set property by creating a temporary object
  final temp = <String, JSAny>{name: value}.jsify() as JSObject;
  _jsObjectAssign(obj, temp);
}

class RecaptchaVerifierImpl implements RecaptchaVerifier {
  final FirebaseAuth auth;

  final String? container;

  final RecaptchaVerifierSize size;

  final RecaptchaVerifierTheme theme;

  final RecaptchaVerifierOnSuccess? onSuccess;

  final RecaptchaVerifierOnError? onError;

  final RecaptchaVerifierOnExpired? onExpired;

  int? widgetId;

  web.HTMLDivElement? _element;

  Completer<String>? _completer;

  RecaptchaVerifierImpl({
    required this.auth,
    this.container,
    this.size = RecaptchaVerifierSize.normal,
    this.theme = RecaptchaVerifierTheme.light,
    this.onSuccess,
    this.onError,
    this.onExpired,
  });

  @override
  void clear() {
    if (widgetId != null) {
      grecaptcha.reset(widgetId!);
      widgetId = null;
      _completer = null;
      _element?.remove();
    }
  }

  @override
  Future<int> render() async {
    await RecaptchaLoader().load();
    if (widgetId == null) {
      var parentElement = container == null
          ? web.document.body!
          : web.document.getElementById(container!) as web.HTMLElement;
      var guaranteedEmpty = web.HTMLDivElement()..id = 'recaptcha';
      parentElement.appendChild(guaranteedEmpty);
      _element = guaranteedEmpty;

      _completer = Completer();

      int? newWidgetId;

      newWidgetId = grecaptcha.render(
          _element!,
          GRecaptchaParameters(
              callback: js.allowInterop((v) {
                if (newWidgetId != widgetId) return;
                if (onSuccess != null) onSuccess!();
                _completer!.complete(v);
              }),
              errorCallback: js.allowInterop((error) {
                var e = FirebaseAuthException('recaptcha-error', '$error');
                if (onError != null) onError!(e);
                _completer!.completeError(e);
              }),
              expiredCallback: js.allowInterop(() {
                if (onExpired != null) onExpired!();
                _completer!
                    .completeError(FirebaseAuthException('recaptcha-expired'));
              }),
              size: container == null ? 'invisible' : size.name,
              theme: theme.name,
              sitekey: await (auth as FirebaseAuthImpl)
                  .rpcHandler
                  .getRecaptchaSiteKey()));
      widgetId = newWidgetId;
    }

    return widgetId!;
  }

  @override
  String get type => 'recaptcha';

  @override
  Future<String> verify() async {
    if (widgetId == null) {
      await render();
    }
    if (container == null) {
      grecaptcha.execute(widgetId!);
    }

    return _completer!.future.whenComplete(() => clear());
  }
}

class RecaptchaLoader {
  static final _instance = RecaptchaLoader._();

  String? _hostLanguage;

  Future<void>? _loadFuture;

  RecaptchaLoader._();

  factory RecaptchaLoader() => _instance;

  bool _isHostLanguageValid(String hl) {
    return hl.length <= 6 && RegExp(r'^\s*[a-zA-Z0-9\-]*\s*$').hasMatch(hl);
  }

  Future<void> load([String hl = '']) {
    if (!_isHostLanguageValid(hl)) {
      throw FirebaseAuthException.argumentError('Invalid hl parameter value.');
    }

    if (_hostLanguage == hl) {
      return _loadFuture!;
    }

    var completer = Completer<void>();

    var r = Random();

    var name = '_gonload${r.nextInt(1000000)}';
    var script = web.HTMLScriptElement()
      ..src = Uri.parse('https://www.google.com/recaptcha/api.js')
          .replace(queryParameters: {
        'render': 'explicit',
        'onload': name,
        if (hl.isNotEmpty) 'hl': hl,
      }).toString()
      ..async = true;

    // Set callback on window using JS interop
    final windowObj = web.window as JSObject;
    final callback = js.allowInterop((_) {
      completer.complete();
    }).toJS;
    // Use JS interop to set property dynamically
    _setJSProperty(windowObj, name, callback);

    web.document.body!.appendChild(script);

    return _loadFuture = completer.future;
  }
}
