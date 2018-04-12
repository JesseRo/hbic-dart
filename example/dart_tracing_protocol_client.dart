import 'dart:io';

main() async {
  var socket = await RawSocket.connect('127.0.0.1', 8888);
  print(socket.runtimeType);
  List<int> templateHead = [0xab, 0xcd, 0xef, 0xfe, 0xdc, 0xba];
  print(templateHead[0].bitLength);
  socket.write(templateHead);
}