import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_tracing_protocol/src/hbic_common.dart';


class ProtocolMode extends Mode{
  static const ProtocolMode EMIT = const ProtocolMode(0);
  static const ProtocolMode SUB_SESSION = const ProtocolMode(1);

  const ProtocolMode(int value) : super(value);

  @override
  List<String> modeStrings() {
    return const[
      'ProtocolMode:EMIT',
      'ProtocolMode:SUB_SESSION',
    ];
  }
}


///  the hbic protocol packet head
///  is made of several parts described below:
///  @protocol sign: 1 bytes
///  @timestamp: 8 bytes
///  @mode: 1 bytes
///  @content length: 4 bytes
///  @TBD: 20 bytes
///  @protocol sign: 1 bytes
///  total 35 bytes long..
class ProtocolHead{
  static final int headLong = 35;
  static final int sign_beginning = 0xab;
  static final int sign_end = 0xba;

  Uint8List head;

  int length;

  ProtocolMode mode;

  int timestamp;

  ProtocolHead.fromBuffer(List<int> buffer){
    this.head = new Uint8List(headLong);
    this.head.setAll(chunkIndex, iterable)
    check();
    mode = head[9] == 0 ? ProtocolMode.EMIT : ProtocolMode.SUB_SESSION;
    length = bytesToInt(head.sublist(6, 14));
    timestamp = bytesToInt(head.sublist(1, 5));
  }

  ProtocolHead(int length, {int timestamp, ProtocolMode mode}){
    if (length < 0){
      throw 'length cannot be negative..';
    }
    this.length = length;
    if (timestamp != null){
      this.timestamp = timestamp;
    }else{
      this.timestamp = new DateTime.now().millisecondsSinceEpoch;
    }

    if(mode != null){
      this.mode = mode;
    }else{
      this.mode = ProtocolMode.EMIT;
    }
  }

  List<int> toBytes(){
    Uint8List bytes = new Uint8List(headLong);
    final bytedata = bytes.buffer.asByteData(0, 14);
    bytedata.setInt8(0, sign_beginning);
    bytedata.setInt64(1, timestamp);
    bytedata.setInt8(9, mode.value);
    bytedata.setInt32(10, length);
    bytes.setRange(14, headLong, new List<int>.filled(20, 0));
    bytes[34] = sign_end;
    return bytes;
  }

  void check() {
    // todo: check if head validate
  }
}

class HbiMessage {
  ProtocolHead head;
  String content;
  List<int> contentBuffer;

  HbiMessage(this.head, this.contentBuffer);

  HbiMessage.fromString(String content){
    this.content = content;
    head = new ProtocolHead(content.length);
    contentBuffer = utf8.encode(content);
  }

  List<int> get buffers{
    List<int> buffers = [];
    buffers.addAll(head.toBytes());
    buffers.addAll(contentBuffer);
    return buffers;
  }


  @override
  String toString() {
    if (content == null){
      content = utf8.decode(contentBuffer);
    }
    return content;
  }
}

