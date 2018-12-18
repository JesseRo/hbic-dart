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
///  @timestamp: 4 bytes
///  @mode: 1 bytes
///  @content length: 8 bytes
///  @TBD: 20 bytes
///  @protocol sign: 1 bytes
///  total 39 bytes long..
class ProtocolHead{
  static int headLong = 35;
  static int sign_beginning = 0xab;
  static int sign_end = 0xba;

  List<int> head;

  int length;

  ProtocolMode mode;

  int timestamp;

  ProtocolHead.fromBuffer(List<int> buffer){
    this.head = buffer;
    check();
    mode = head[5] == 0 ? ProtocolMode.EMIT : ProtocolMode.SUB_SESSION;
    length = bytesToInt(head.sublist(6, 14));
    timestamp = bytesToInt(head.sublist(1, 5));
  }

  ProtocolHead(int length, {timestamp: int, mode: ProtocolMode}){
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
    assert (timestamp.bitLength < 32, 'too long the timestamp is...');
    List<int> bytes = new List(headLong);
    bytes[0] = sign_beginning;
    bytes.replaceRange(1, 5, intToBytes(timestamp));
    bytes[5] = mode.value;
    bytes.replaceRange(6, 14, intToBytes(length));
    bytes.fillRange(14, 34, 0);
    bytes[34] = sign_end;
    return bytes;
  }

  void check() {
    // todo: check if head validate
  }
}

