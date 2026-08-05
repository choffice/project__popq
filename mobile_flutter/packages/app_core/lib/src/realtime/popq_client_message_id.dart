import 'package:uuid/uuid.dart';

abstract final class PopqClientMessageId {
  static final Uuid _uuid = Uuid();

  static String generate() {
    return _uuid.v4();
  }
}