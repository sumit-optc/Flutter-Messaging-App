import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ConnectionScreen(),
    );
  }
}

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // Default values
    _ipController.text = '10.0.2.2'; // Default for Android emulator
    _portController.text = '3000';
    _nameController.text =
        'User${DateTime.now().millisecondsSinceEpoch % 1000}';
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _connect() {
    if (_formKey.currentState!.validate()) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            serverIP: _ipController.text,
            serverPort: _portController.text,
            userName: _nameController.text,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect to Chat'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                controller: _ipController,
                decoration: const InputDecoration(
                  labelText: 'Server IP',
                  hintText: 'Enter server IP address',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter server IP';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _portController,
                decoration: const InputDecoration(
                  labelText: 'Server Port',
                  hintText: 'Enter server port',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter server port';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Your Name',
                  hintText: 'Enter your name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _connect,
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 48, vertical: 12),
                ),
                child: const Text('Connect'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String serverIP;
  final String serverPort;
  final String userName;

  const ChatScreen({
    super.key,
    required this.serverIP,
    required this.serverPort,
    required this.userName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  WebSocketChannel? channel;
  bool isConnected = false;
  bool isConnecting = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    connectToServer();
  }

  @override
  void dispose() {
    channel?.sink.close();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> connectToServer() async {
    if (isConnecting) return;

    setState(() {
      isConnecting = true;
    });

    try {
      final wsUrl = 'ws://${widget.serverIP}:${widget.serverPort}';
      print('Connecting to $wsUrl as ${widget.userName}');

      channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      // Wait for the connection to establish
      await channel!.ready;
      print('WebSocket connection established');

      channel!.stream.listen(
        (message) {
          print('Received message: $message');
          setState(() {
            final parts = message.toString().split(':');
            if (parts.length >= 2) {
              final sender = parts[0];
              final content = parts.sublist(1).join(':');
              _messages.add(ChatMessage(
                sender: sender,
                content: content,
                isMe: sender == widget.userName,
              ));
              // Scroll to bottom when new message arrives
              Future.delayed(
                  const Duration(milliseconds: 100), _scrollToBottom);
            }
          });
        },
        onError: (error) {
          print('WebSocket error: $error');
          _showError('Connection error: $error');
          setState(() {
            isConnected = false;
            isConnecting = false;
          });
        },
        onDone: () {
          print('WebSocket connection closed');
          _showError('Disconnected from server');
          setState(() {
            isConnected = false;
            isConnecting = false;
          });
        },
      );

      setState(() {
        isConnected = true;
        isConnecting = false;
      });

      // Send a test message to verify connection
      channel!.sink.add('${widget.userName}:connected');
    } catch (e) {
      print('Connection error: $e');
      _showError('Failed to connect: $e');
      setState(() {
        isConnected = false;
        isConnecting = false;
      });
    }
  }

  void _sendMessage() {
    if (_controller.text.isNotEmpty && channel != null) {
      final message = '${widget.userName}:${_controller.text}';
      print('Sending message: $message');
      try {
        channel!.sink.add(message);
        _controller.clear();
        // Scroll to bottom when sending message
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      } catch (e) {
        print('Error sending message: $e');
        _showError('Failed to send message: $e');
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat as ${widget.userName}'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Container(
            margin: const EdgeInsets.all(16),
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isConnected ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              padding: const EdgeInsets.all(8),
              itemBuilder: (context, index) {
                final message = _messages[index];
                return MessageBubble(message: message);
              },
            ),
          ),
          if (!isConnected)
            Container(
              color: Colors.red[100],
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Disconnected. Tap to reconnect.'),
                  ),
                  TextButton(
                    onPressed: connectToServer,
                    child: const Text('Reconnect'),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Enter message',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: isConnected ? _sendMessage : null,
                  child: const Text('Send'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String sender;
  final String content;
  final bool isMe;
  final DateTime timestamp;

  ChatMessage({
    required this.sender,
    required this.content,
    required this.isMe,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: message.isMe ? Colors.blue[100] : Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.sender,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 4),
            Text(message.content),
          ],
        ),
      ),
    );
  }
}
