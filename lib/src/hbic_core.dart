import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dart_tracing_protocol/src/hbic_common.dart';
import 'package:dart_tracing_protocol/src/protocol_base.dart';
import 'package:dart_tracing_protocol/src/protocol_packet.dart';
import 'package:logging/logging.dart';

Logger log = new Logger("protocol buffer stream");

class AbstractHBIC{
  RawSocket rawSocket;
  var context;
  // mark if the sending pipeline is available
  bool available;
  AbstractHBIC(ContextFactor factor, RawSocket rawSocket){
    this.context = factor();
    bind(rawSocket);
  }
  // waiters wait until a full message is collected
  Queue<Completer<HbiMessage>> waiters = new Queue();
  // sending pipeline
  Queue<WriteIntend> pipeline = new Queue<WriteIntend>();

  Queue<HbiMessage> products = new Queue();

  HbiMessageProducer producer = new HbiMessageProducer();



  void bind(RawSocket rawSocket){
    SocketProtocol protocol = new SocketProtocol(this);
    rawSocket.writeEventsEnabled = false;
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
    this.rawSocket = rawSocket;
  }

  void comingBuffer(List<int> buffer){
    List<int> remain = producer.feed(buffer);
    if(remain == null){
      return;
    }else{
      products.addLast(producer.produce());
    }
    while(products.length > 0){
      if(waiters.length > 0){
        Completer<HbiMessage> waiter = waiters.removeFirst();
        if(waiter.isCompleted){
          throw 'future is already completed..';
        }
        waiter.complete(products.removeFirst());
      }else{
        break;
      }
    }
    if(remain.length > 0){
      comingBuffer(remain);
    }
  }

  Future<HbiMessage> fetch() async {
    Completer<HbiMessage> completer = new Completer();
    Future<HbiMessage> future = completer.future;
    waiters.addLast(completer);
    return future;
  }

  Future<void> send(HbiMessage message) async {
    Completer completer = new Completer();
    Future future = completer.future;

    WriteIntend intend = new WriteIntend(message.buffers, completer);
    pipeline.addLast(intend);
    rawSocket.writeEventsEnabled = true;
    return future;
  }
}


class MessageConsumeStatus extends Mode{
  static const MessageConsumeStatus EXPLORING = const MessageConsumeStatus(0);
  static const MessageConsumeStatus MATCHINGHEAD = const MessageConsumeStatus(1);
  static const MessageConsumeStatus MATCHINGCONTENT = const MessageConsumeStatus(2);

  const MessageConsumeStatus(int value) : super(value);

  @override
  List<String> modeStrings() {
    return const[
      'MessageConsumeMode:EXPLORING',
      'MessageConsumeMode:MATCHINGHEAD',
      'MessageConsumeMode:MATCHINGCONTENT',
    ];
  }

}

class HbiMessageProducer{
  Uint8List contentBuffer;
  int expectedLength;
  int chunkIndex;
  int headIndex;
  Uint8List headBuffer;
  ProtocolHead head;
  MessageConsumeStatus status;

  void reset() {
    this.contentBuffer = null;
    this.expectedLength = 0;
    this.chunkIndex = 0;
    this.headIndex = 0;
    this.status = MessageConsumeStatus.EXPLORING;
    this.headBuffer = new Uint8List(ProtocolHead.headLong);
  }

  HbiMessageProducer(){
    reset();
  }

  List<int> feed(List<int> chunk){
    switch(status.value){
      case 0:
        chunkIndex = chunk.indexOf(ProtocolHead.sign_beginning);
        if(chunkIndex >= 0){
          status = MessageConsumeStatus.MATCHINGHEAD;
          expectedLength = chunkIndex + ProtocolHead.headLong;
          continue MatchingHead;
        }
        return null;
      MatchingHead:
      case 1:
        if(expectedLength > chunk.length){
          headBuffer.setRange(headIndex, headIndex + chunk.length - chunkIndex, chunk, chunkIndex);
          headIndex = chunk.length - chunkIndex;
          expectedLength = expectedLength - chunk.length;
          chunkIndex = 0;
        }else{
          if(chunk[expectedLength - 1] == ProtocolHead.sign_end){
            headBuffer.setRange(headIndex, 
                headIndex + expectedLength, chunk, chunkIndex);
            head = new ProtocolHead.fromBuffer(headBuffer);
            status = MessageConsumeStatus.MATCHINGCONTENT;
            contentBuffer = new Uint8List(head.length);
            headIndex = 0;
            if(expectedLength == chunk.length){
              // head.length is the length(by bytes) of the message body
              expectedLength = head.length;
              return null;
            }else {
              chunkIndex = expectedLength;
//              chunk = chunk.sublist(expectedLength);
              expectedLength += head.length;
              continue MatchingContent;
            }
          }
        }
        return null;
      MatchingContent:
      case 2:
        if(expectedLength < chunk.length){
          contentBuffer.setRange(headIndex, contentBuffer.lengthInBytes, chunk, chunkIndex);
          // returning a non-empty list means the message body is full-filled
          // and returns the remaining buffer
          return chunk.sublist(expectedLength);
        }else if(expectedLength == chunk.length){
          contentBuffer.setRange(headIndex, contentBuffer.lengthInBytes, chunk, chunkIndex);
          // returning empty list means the message body is perfectly full-filled
          return [];
        }else{
          contentBuffer.setRange(headIndex, headIndex + chunk.length - chunkIndex, chunk, chunkIndex);
          headIndex += chunk.length - chunkIndex;
          chunkIndex = 0;
          // returning null means the message body is not full-filled..
          return null;
        }
        break;
      default:
        throw 'there should not be other phrase..';
    }
  }

  HbiMessage produce(){
    HbiMessage message = new HbiMessage(head, contentBuffer);
    reset();
    return message;
  }
}
