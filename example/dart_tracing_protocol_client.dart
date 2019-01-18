import 'dart:io';

import 'package:dart_tracing_protocol/src/protocol_head.dart';

main() async {
  var socket = await RawSocket.connect('127.0.0.1', 8888);
  print(socket.runtimeType);
  List<int> templateHead = new ProtocolHead(5).toBytes();
  print(templateHead[0].bitLength);
  socket.write(templateHead);
  socket.write("hello".codeUnits);
}