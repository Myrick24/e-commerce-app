import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ChatDetailScreen extends StatefulWidget {
  final String chatId;
  final String otherPartyName;
  final String sellerId;
  final String customerId;
  final bool isSeller;

  const ChatDetailScreen({
    Key? key,
    required this.chatId,
    required this.otherPartyName,
    required this.sellerId,
    required this.customerId,
    required this.isSeller,
  }) : super(key: key);

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    // Mark messages as read when opening the chat
    _markMessagesAsRead();
    
    // Add listener to scroll to bottom when keyboard appears
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }
  
  @override
  void dispose() {
    _messageController.dispose();
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
  
  Future<void> _markMessagesAsRead() async {
    try {
      // Get the chat document
      final chatDoc = await _firestore.collection('chats').doc(widget.chatId).get();
      
      if (!chatDoc.exists) {
        return;
      }
      
      // Update unread count based on user type
      if (widget.isSeller) {
        await _firestore.collection('chats').doc(widget.chatId).update({
          'unreadSellerCount': 0
        });
      } else {
        await _firestore.collection('chats').doc(widget.chatId).update({
          'unreadCustomerCount': 0
        });
      }
      
      // Mark all messages as read
      final batch = _firestore.batch();
      final messagesQuery = await _firestore
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .where('isRead', isEqualTo: false)
          .where('senderId', isNotEqualTo: _auth.currentUser!.uid)
          .get();
          
      for (final doc in messagesQuery.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      
      await batch.commit();
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;
    
    setState(() {
      _isSending = true;
    });
    
    try {
      final currentUserId = _auth.currentUser!.uid;
      final timestamp = FieldValue.serverTimestamp();
      
      // Check if chat document exists
      final chatDoc = await _firestore.collection('chats').doc(widget.chatId).get();
      
      if (!chatDoc.exists) {
        // Create new chat document if it doesn't exist
        await _firestore.collection('chats').doc(widget.chatId).set({
          'sellerId': widget.sellerId,
          'customerId': widget.customerId,
          'createdAt': timestamp,
          'lastMessage': messageText,
          'lastMessageTimestamp': timestamp,
          'lastSenderId': currentUserId,
          'unreadCustomerCount': widget.isSeller ? 1 : 0,
          'unreadSellerCount': widget.isSeller ? 0 : 1,
        });
      } else {
        // Update existing chat document
        await _firestore.collection('chats').doc(widget.chatId).update({
          'lastMessage': messageText,
          'lastMessageTimestamp': timestamp,
          'lastSenderId': currentUserId,
          // Increment unread count for recipient
          widget.isSeller ? 'unreadCustomerCount' : 'unreadSellerCount': FieldValue.increment(1),
        });
      }
      
      // Add message to subcollection
      await _firestore
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add({
            'text': messageText,
            'senderId': currentUserId,
            'timestamp': timestamp,
            'isRead': false,
          });
          
      // Clear input field
      _messageController.clear();
      
      // Scroll to the bottom to show new message
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: Text(
          widget.otherPartyName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('timestamp')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                
                final messages = snapshot.data?.docs ?? [];
                
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No messages yet',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Start the conversation!',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                // After loading messages, mark them as read and scroll to bottom
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _markMessagesAsRead();
                  _scrollToBottom();
                });
                
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final messageData = messages[index].data() as Map<String, dynamic>;
                    final messageText = messageData['text'] as String? ?? '';
                    final senderId = messageData['senderId'] as String? ?? '';
                    final timestamp = messageData['timestamp'] as Timestamp?;
                    final isRead = messageData['isRead'] as bool? ?? false;
                    
                    final isMe = senderId == _auth.currentUser!.uid;
                    final time = timestamp?.toDate();
                    final timeString = time != null 
                        ? DateFormat('h:mm a').format(time)
                        : '';
                    
                    return MessageBubble(
                      message: messageText,
                      isMe: isMe,
                      time: timeString,
                      isRead: isRead,
                    );
                  },
                );
              },
            ),
          ),
          
          // Input area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                // Message input field
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                
                // Send button
                Container(
                  height: 45,
                  width: 45,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: _isSending 
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white),
                    onPressed: _isSending ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  final String message;
  final bool isMe;
  final String time;
  final bool isRead;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isMe,
    required this.time,
    required this.isRead,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isMe) 
            Padding(
              padding: const EdgeInsets.only(right: 4.0),
              child: Text(
                time,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
              ),
            ),
            
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 10.0,
              ),
              decoration: BoxDecoration(
                color: isMe ? Colors.green : Colors.grey[200],
                borderRadius: BorderRadius.circular(20.0).copyWith(
                  bottomRight: isMe ? const Radius.circular(0) : null,
                  bottomLeft: isMe ? null : const Radius.circular(0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                    ),
                  ),
                  if (isMe)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isRead ? Icons.done_all : Icons.done,
                          size: 14,
                          color: isMe ? (isRead ? Colors.white : Colors.white70) : Colors.grey,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 4.0),
              child: Text(
                time,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
              ),
            ),
        ],
      ),
    );
  }
}