import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:dart_tracing_protocol/src/hbic_common.dart';
import 'package:dart_tracing_protocol/src/protocol_head.dart';
import 'package:logging/logging.dart';

Logger log = new Logger("protocol buffer stream");

class AbstractHBIC{
  RawSocket rawSocket;
  var context;
  // mark if the sending pipeline is available
  bool available;
  AbstractHBIC(this.context, this.rawSocket);

  Queue<Completer<HbiMessage>> waiters = new Queue();
  Queue<Completer<HbiMessage>> pipeline = new Queue();
  Queue<HbiMessage> products = new Queue();

  HbiMessageProducer producer = new HbiMessageProducer();

  void comingBuffer(List<int> buffer){
    List<int> remain = producer.feed(buffer);
    if(remain == null){
      return;
    }else if(remain.length == 0){
      products.addLast(producer.produce());
    }else{
      products.addLast(producer.produce());
      comingBuffer(remain);
    }
    while(products.length > 0){
      if(waiters.length > 0){
        Completer<HbiMessage> waiter = waiters.removeFirst();
        if(waiter.isCompleted){
          throw 'future is already completed..';
        }
        waiter.complete(products.removeFirst());
      }
    }
  }

  Future<HbiMessage> fetch() async {
    Completer<HbiMessage> completer = new Completer();
    Future<HbiMessage> future = completer.future;
    waiters.addLast(completer);
    return future;
  }

  Future send(HbiMessage message) async {
    Completer completer = new Completer();
    Future future = completer.future;
    pipeline.addLast(completer);
    return future;
  }
}

class HbiMessage {
  ProtocolHead head;
  List<int> buffers;

  HbiMessage(this.head, this.buffers);
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
  var buffers;
  var contentBuffer;
  var expectedLength;
  var index;
  ProtocolHead head;
  MessageConsumeStatus status;

  void reset() {
    this.buffers = <List<int>>[];
    this.contentBuffer = new List<int>();
    this.expectedLength = 0;
    this.index = 0;
    this.status = MessageConsumeStatus.EXPLORING;
  }

  HbiMessageProducer(){
    reset();
  }

  List<int> feed(List<int> buffer){
    switch(status.value){
      case 0:
        index = buffer.indexOf(ProtocolHead.sign_beginning);
        if(index >= 0){
          status = MessageConsumeStatus.MATCHINGHEAD;
          expectedLength = index + ProtocolHead.headLong;
          continue MatchingHead;
        }
        return null;
      MatchingHead:
      case 1:
        if(expectedLength > buffer.length){
          expectedLength = expectedLength - buffer.length;
          buffers.add(buffer);
          index = 0;
        }else{
          if(buffer[expectedLength - 1] == ProtocolHead.sign_end){
            var headBuffer = new List<int>();
            for(List<int> bf in buffers){
              headBuffer.addAll(bf);
            }
            headBuffer.addAll(buffer.sublist(index, expectedLength));
            head = new ProtocolHead.fromBuffer(headBuffer);
            status = MessageConsumeStatus.MATCHINGCONTENT;
            buffers.clear();
            if(expectedLength < buffer.length){
              buffer = buffer.sublist(expectedLength);
              continue MatchingContent;
            }
          }
        }
        return null;
      MatchingContent:
      case 2:
      // head.length is the length(by bytes) of the message body
        if(expectedLength == 0){
          expectedLength = head.length;
        }
        if(expectedLength < buffer.length){
          contentBuffer.addAll(buffer.sublist(0, expectedLength));
          reset();
          // returning a non-empty list means the message body is full-filled
          // and returns the remaining buffer
          return buffer.sublist(expectedLength);
        }else if(expectedLength == buffer.length){
          contentBuffer.addAll(buffer);
          reset();
          // returning empty list means the message body is perfectly full-filled
          return [];
        }else{
          contentBuffer.addAll(buffer);
          // returning null means the message body is not full-filled..
          return null;
        }
        break;
      default:
        throw 'there should not be other phrase..';
    }
  }

  HbiMessage produce(){
    return new HbiMessage(head, contentBuffer);
  }
}
