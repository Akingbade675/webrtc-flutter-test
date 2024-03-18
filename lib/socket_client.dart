import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketClient {
  IO.Socket? _socket;

  SocketClient._privateConstructor() {
    _socket = IO.io(
      'http://localhost:3000',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    _socket?.onConnect((_) {
      print('socket connected');
    });
  }

  static final SocketClient _instance = SocketClient._privateConstructor();

  factory SocketClient() {
    return _instance;
  }

  IO.Socket? get socket => _socket;

  void connect() {
    _socket?.connect();
  }

  void disconnect() {
    _socket?.disconnect();
  }

  void emit(String event, dynamic data) {
    _socket?.emit(event, data);
  }

  void on(String event, dynamic Function(dynamic) callback) {
    _socket?.on(event, callback);
  }

  void close() {
    _socket?.close();
  }
}
