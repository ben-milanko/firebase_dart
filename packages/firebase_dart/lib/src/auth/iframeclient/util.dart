import 'dart:js_interop';

@JS('window')
external JSObject get _window;

dynamic getObjectRef(String ref) {
  // Use dart:js_interop to access global context
  dynamic m = _window;
  for (var k in ref.split('.')) {
    m = m?[k];
  }
  return m;
}

class Delay {
  final Duration minDelay;
  final Duration maxDelay;

  Delay(this.minDelay, this.maxDelay);

  Duration get() => maxDelay;
}
