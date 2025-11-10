// ignore_for_file: non_constant_identifier_names

@JS('gapi.iframes')
library;

import 'package:js/js.dart';
import 'package:web/web.dart' as web;

@JS()
external Context getContext();

@JS()
class Iframe {
  external IThenable ping();

  external void restyle(IframeRestyleOptions parameters);

  external void send(
      String type, dynamic data, Function onDone, IframesFilter filter);

  external void register(String eventName, IframeEventHandler callback,
      [IframesFilter filter]);
  external void unregister(String eventName, IframeEventHandler callback);
}

@JS()
@anonymous
abstract class Context {
  external void openChild(IframeOptions options);

  external void open(IframeOptions options, [Function(Iframe) onOpen]);
}

@JS()
@anonymous
abstract class IframeAttributes {
  external web.CSSStyleDeclaration? style;

  external factory IframeAttributes({web.CSSStyleDeclaration? style});
}

@JS()
@anonymous
abstract class IframeRestyleOptions {
  external bool? setHideOnLeave;

  external factory IframeRestyleOptions({bool? setHideOnLeave});
}

@JS()
@anonymous
abstract class IframeEvent {
  external String type;

  external IframeAuthEvent? authEvent;
}

@JS()
@anonymous
abstract class IframeEventHandlerResponse {
  external String status;

  external factory IframeEventHandlerResponse({String status});
}

typedef IframeEventHandler = IframeEventHandlerResponse Function(
    IframeEvent, Iframe);

@JS()
@anonymous
abstract class IframeAuthEvent {
  external String? eventId;

  external String? postBody;

  external String? sessionId;

  external String? providerId;

  external String? tenantId;

  external String type;

  external String? urlResponse;

  external IframeError? error;
}

@JS()
@anonymous
abstract class IframeError {
  external String code;

  external String message;
}

@JS()
@anonymous
abstract class IframeOptions {
  external String get url;
  external web.HTMLElement? get where;
  external IframeAttributes? get attributes;
  external IframesFilter? messageHandlersFilter;
  external bool? dontclear;

  external factory IframeOptions(
      {String url,
      web.HTMLElement? where,
      IframeAttributes? attributes,
      IframesFilter? messageHandlersFilter,
      bool? dontclear});
}

@JS()
@anonymous
abstract class IThenable {
  external void then(Function callback, Function onError);
}

@JS()
external IframesFilter get CROSS_ORIGIN_IFRAMES_FILTER;

@JS()
abstract class IframesFilter {}
