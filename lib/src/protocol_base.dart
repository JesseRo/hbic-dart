import 'dart:async';
import 'dart:collection';
// TODO: Put public facing types in this file.
import 'dart:io';

import 'package:dart_tracing_protocol/src/hbic_core.dart';

import 'protocol_packet.dart';
import 'package:logging/logging.dart';

typedef void DataHandler(List<int> bytes);
typedef void EventHandler();
typedef void ErrorHandler();

Logger log = new Logger("protocol base");


abstract class Protocol{
  onDataReceived(data);

  onSocketMade(socket);

  onClosed();

  onReadClosed();

  onError(error);

  onDone();

  onWrite();
}

class SocketProtocol extends Protocol{
  AbstractHBIC hbic;
  int offset = 0;
  WriteIntend intend = null;

  SocketProtocol(this.hbic);
  @override
  onDataReceived(data) {
    log.fine('socket on dataReceived.');
    log.shout(data);
    hbic.comingBuffer(data);
  }

  @override
  onWrite() {
    log.fine('socket on write.');
    if (intend == null) {
      if (hbic.pipeline.length == 0) {
        log.severe('no data to write.');
        return;
      } else {
        intend = hbic.pipeline.removeFirst();
      }
    }

    offset += hbic.rawSocket.write(intend.buffer, offset, intend.buffer.length - offset);
    if (offset < intend.buffer.length){
      hbic.rawSocket.writeEventsEnabled = true;
    }
    if(offset == intend.buffer.length){
      intend.completer.complete();
      offset = 0;
      intend = null;
      log.fine('one message send succeed.');
    }
  }

  @override
  onReadClosed() {
    log.fine('socket on readClosed.');
    return null;
  }

  @override
  onClosed() {
    log.fine('socket on closed.');
    return null;
  }

  @override
  onError(error) {
    log.fine('socket on error: $error.');
    return null;
  }

  @override
  onDone() {
    log.fine('socket on done.');
  }

  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class WriteIntend{
  List<int> buffer ;
  Completer completer;

  WriteIntend(this.buffer, this.completer);
}

class ServerProtocol extends Protocol{

  HbiServer hbiServer;
  Logger logger = new Logger("protocol base");
  ServerProtocol(this.hbiServer);

  @override
  onError(error) {
    // some error occurs...
    // this server may shut down improperly
    // try keeping the concurrent..
    log.fine('server on error: $error.');
    return null;
  }

  @override
  onDone() {
    // should not be emit
    // unless be shut down on purpose
    log.fine('server on done.');
    return null;
  }

  @override
  onSocketMade(rawSocket/* type: RawSocket */) {
    var hbic = new AbstractHBIC(hbiServer.factor, rawSocket);
  }

  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

typedef ContextFactor();

class HbiServer {
  ContextFactor factor;

  Future<StreamSubscription<RawSocket>> initServer({port: int, Protocol serverProtocol, ContextFactor factor}) async{
    this.factor = factor;
    if(factor == null){
      this.factor = ()=>{};
    }
    if(serverProtocol == null){
      serverProtocol = new ServerProtocol(this);
    }
    RawServerSocket serverSocket = await RawServerSocket.bind(InternetAddress.ANY_IP_V4, port);
    return serverSocket.listen(serverProtocol.onSocketMade, onError: serverProtocol.onError, onDone: serverProtocol.onDone);
  }
}

