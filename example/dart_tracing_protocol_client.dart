import 'dart:convert';
import 'dart:io';

import 'package:dart_tracing_protocol/src/hbic_core.dart';
import 'package:dart_tracing_protocol/src/protocol_packet.dart';

main() async {

  var rawSocket = await RawSocket.connect("127.0.0.1", 8888);
  AbstractHBIC hbic = new AbstractHBIC(()=>{}, rawSocket);
  await hbic.send(new HbiMessage.fromString(json.encode({'a': 'sb', 'b': 'genius'})));
  await hbic.send(new HbiMessage.fromString(json.encode({'c': 'luohuaixi', 'd': 'zhoudongdong'})));
  await hbic.send(new HbiMessage.fromString(json.encode({'e': 'xige', 'f': 'guaiguailp'})));

  print("client send over.");
}