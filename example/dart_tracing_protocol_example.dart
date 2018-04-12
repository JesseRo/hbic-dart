import 'package:dart_tracing_protocol/dart_tracing_protocol.dart';
import 'package:logging/logging.dart';

main() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((LogRecord rec) {
    print('${rec.loggerName}: ${rec.time}: [${rec.level.name.substring(0, 4)}]  ${rec.message} ');
  });
  var awesome = new AbstractHBIC();
  awesome.initServer(port: 8888);
}
