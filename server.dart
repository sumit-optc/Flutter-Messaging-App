import 'dart:io';
// import 'dart:convert';

void main() async {
  final server = await HttpServer.bind(InternetAddress.anyIPv4, 3000);
  print('WebSocket server running on port 3000');
  print('For Android emulators, use 10.0.2.2:3000');
  print('Local IP addresses:');
  for (var interface in await NetworkInterface.list()) {
    for (var addr in interface.addresses) {
      print('${interface.name}: ${addr.address}');
    }
  }

  final clients = <String, WebSocket>{};

  await for (HttpRequest request in server) {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      print(
          'New connection request from ${request.connectionInfo?.remoteAddress}');
      try {
        WebSocket ws = await WebSocketTransformer.upgrade(request);
        handleClient(ws, clients);
      } catch (e) {
        print('Error upgrading connection: $e');
      }
    }
  }
}

void handleClient(WebSocket client, Map<String, WebSocket> clients) {
  String? clientId;

  client.listen(
    (message) {
      print('Received message: $message');
      try {
        final parts = message.toString().split(':');
        if (parts.length >= 2) {
          final sender = parts[0];

          if (clientId == null) {
            clientId = sender;
            clients[clientId!] = client;
            print('Client registered: $clientId');
            print('Total connected clients: ${clients.length}');
          }

          print('Broadcasting message to ${clients.length} clients');
          for (var entry in clients.entries) {
            try {
              if (entry.value.readyState == WebSocket.open) {
                entry.value.add(message);
                print('Message sent to ${entry.key}');
              } else {
                print('Client ${entry.key} connection not open');
              }
            } catch (e) {
              print('Error sending to ${entry.key}: $e');
            }
          }
        }
      } catch (e) {
        print('Error processing message: $e');
      }
    },
    onDone: () {
      print('Client disconnected: $clientId');
      if (clientId != null) {
        clients.remove(clientId);
      }
      print('Remaining connected clients: ${clients.length}');
    },
    onError: (error) {
      print('Error from client $clientId: $error');
      if (clientId != null) {
        clients.remove(clientId);
      }
      print('Remaining connected clients: ${clients.length}');
    },
  );
}
