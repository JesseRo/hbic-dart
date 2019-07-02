abstract class Mode {

  final int _value;
  const Mode(this._value);

  List<String> modeStrings();

  get value => _value;

  String toString() {
    return modeStrings()[_value];
  }
}

List<int> intToBytes(int number){
  int length = (number.bitLength / 8).ceil();
  var bytes = new List(length);
  for(int i = 0; i < length; i++){
    bytes[i] = (number >> (i * 8)) & 0xff;
  }
  return bytes;
}

int bytesToInt(List<int> bytes) {
  int value = 0;
  for(int i = 0; i < bytes.length; i++){
    value += bytes[bytes.length - 1 - i] << i * 8;
  }
  return value;
}

