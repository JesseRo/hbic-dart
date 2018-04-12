import 'dart:async';
import 'dart:convert';
// TODO: Put public facing types in this file.
import 'dart:io';

import 'package:logging/logging.dart';
/// Checks if you are awesome. Spoiler: you are.

typedef void DataHandler(List<int> bytes);
typedef void EventHandler();
typedef void ErrorHandler();

List<int> templateHead = [0xab, 0xcd, 0xef, 0xfe, 0xdc, 0xba];

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
  SocketProtocol(this.hbic);
  @override
  onDataReceived(data) {
    log.fine('socket on dataReceived.');
    log.shout(data);
    return null;
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
  onWrite() {
    log.fine('socket on write.');
  }

  @override
  onDone() {
    log.fine('socket on done.');
  }

  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ServerProtocol extends Protocol{

  Logger logger = new Logger("protocol base");
  
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
    var hbic = new AbstractHBIC();
    hbic.rawSocket = rawSocket;
    SocketProtocol protocol = new SocketProtocol(hbic);

    var eventHandler = (event){
      switch(event){
        case RawSocketEvent.READ:
          var len = rawSocket.available();
          if(len > 0){
            log.shout(len);
            var bytes = rawSocket.read(len);
            protocol.onDataReceived(bytes);
          }
          break;
        case RawSocketEvent.CLOSED:
          protocol.onClosed();
          break;
        case RawSocketEvent.READ_CLOSED:
          protocol.onReadClosed();
          break;
        case RawSocketEvent.WRITE:
          protocol.onWrite();
          break;
      }
    };
    rawSocket.listen(eventHandler, onError: protocol.onReadClosed(), onDone: protocol.onDone());
  }

  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class AbstractHBIC {
  RawSocket rawSocket;

  void initServer({port: int, Protocol serverProtocol}) async{
    if(serverProtocol == null){
      serverProtocol = new ServerProtocol();
    }
    RawServerSocket serverSocket = await RawServerSocket.bind(InternetAddress.ANY_IP_V4, port);
    serverSocket.listen(serverProtocol.onSocketMade, onError: serverProtocol.onError, onDone: serverProtocol.onDone);
  }
}
