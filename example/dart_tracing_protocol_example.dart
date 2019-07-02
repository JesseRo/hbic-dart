import 'package:dart_tracing_protocol/dart_tracing_protocol.dart';
import 'package:dart_tracing_protocol/src/hbic_core.dart';
import 'package:logging/logging.dart';
import 'dart:async';

class MyProtocol extends ServerProtocol{
  Logger log = new Logger("protocol base");

  MyProtocol(HbiServer hbiServer) : super(hbiServer);
  @override
  onSocketMade(rawSocket/* type: RawSocket */) async {
    var hbic = new AbstractHBIC(hbiServer.factor, rawSocket);
    var message = await hbic.fetch();
    log.shout(message.toString());
  }
}

main() async{
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((LogRecord rec) {
    print('${rec.loggerName}: ${rec.time}: [${rec.level.name.substring(0, 4)}]  ${rec.message} ');
  });
  var awesome = new HbiServer();
  ServerProtocol protocol = new MyProtocol(awesome);
  await awesome.initServer(port: 8888, serverProtocol: protocol);
}
