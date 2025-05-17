import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/user_service.dart';
import '../../services/notification_service.dart';

class SellerRequestDetailPage extends StatefulWidget {
  final String sellerId;
  
  const SellerRequestDetailPage({
    Key? key,
    required this.sellerId,
  }) : super(key: key);

  @override
  State<SellerRequestDetailPage> createState() => _SellerRequestDetailPageState();
}

class _SellerRequestDetailPageState extends State<SellerRequestDetailPage> {
  final UserService _userService = UserService();
  final NotificationService _notificationService = NotificationService();
  final _messageController = TextEditingController();
  
  bool _isLoading = true;
  bool _isProcessing = false;
  Map<String, dynamic>? _sellerData;

  @override
  void initState() {
    super.initState();
    print('SellerRequestDetailPage initialized with sellerId: ${widget.sellerId}');
    _loadSellerData();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadSellerData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      Map<String, dynamic>? userData = await _userService.getUserData(widget.sellerId);
      print('Loaded seller data: $userData');
      
      if (mounted) {
        setState(() {
          _sellerData = userData;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading seller data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _approveSeller() async {
    setState(() {
      _isProcessing = true;
    });
    
    try {
      String message = _messageController.text.trim();
      
      bool success = await _userService.approveSeller(widget.sellerId);
      if (success) {
        // Send notification to the seller
        await _notificationService.sendNotificationToUser(
          userId: widget.sellerId,
          title: 'Seller Approval',
          message: message.isNotEmpty
              ? 'Congratulations! You have been approved as a seller. ${message}'
              : 'Congratulations! You have been approved as a seller. You can now start listing your products.',
          type: 'seller_approval',
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Seller approved successfully')),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      print('Error approving seller: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to approve seller')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _rejectSeller() async {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a reason for rejection')),
      );
      return;
    }
    
    setState(() {
      _isProcessing = true;
    });
    
    try {
      String message = _messageController.text.trim();
      
      bool success = await _userService.rejectSeller(widget.sellerId);
      if (success) {
        // Send notification to the seller
        await _notificationService.sendNotificationToUser(
          userId: widget.sellerId,
          title: 'Seller Application',
          message: 'Your application to become a seller has been rejected. $message',
          type: 'seller_rejection',
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Seller rejected')),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      print('Error rejecting seller: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to reject seller')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seller Request Details'),
        backgroundColor: Colors.green,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sellerData == null
              ? const Center(child: Text('Seller data not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSellerInfoCard(),
                      const SizedBox(height: 24),
                      _buildDocumentsSection(),
                      const SizedBox(height: 24),
                      _buildAdminMessageSection(),
                      const SizedBox(height: 24),
                      _buildActionButtons(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSellerInfoCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Seller Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Name', _sellerData!['name'] ?? 'Not provided'),
            _buildInfoRow('Email', _sellerData!['email'] ?? 'Not provided'),
            _buildInfoRow('Phone', _sellerData!['phone'] ?? 'Not provided'),
            _buildInfoRow('Location', _sellerData!['location'] ?? 'Not provided'),
            _buildInfoRow(
              'Registration Date',
              _formatTimestamp(_sellerData!['createdAt']),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsSection() {
    // Check if seller has uploaded any documents
    List<dynamic> documents = _sellerData!['documents'] ?? [];
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Verification Documents',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (documents.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No documents provided'),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: documents.length,
                itemBuilder: (context, index) {
                  return _buildDocumentItem(documents[index]);
                },
              ),
            if (_sellerData!['description'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Seller Description',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_sellerData!['description']),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentItem(String documentUrl) {
    print('Loading document image: $documentUrl');
    return GestureDetector(
      onTap: () {
        // Show full image in dialog
        showDialog(
          context: context,
          builder: (context) => Dialog(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBar(
                  title: const Text('Verification Document'),
                  leading: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Flexible(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.network(
                      documentUrl,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        print('Error loading image: $error');
                        return Container(
                          color: Colors.grey.shade200,
                          child: const Icon(
                            Icons.broken_image,
                            color: Colors.grey,
                            size: 50,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            documentUrl,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              print('Error loading thumbnail: $error');
              return Container(
                color: Colors.grey.shade200,
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.broken_image, color: Colors.grey, size: 30),
                    SizedBox(height: 4),
                    Text('Image not available', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAdminMessageSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Message to Seller',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _messageController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Enter a message to the seller (optional for approval, required for rejection)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('Approve Seller'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _isProcessing ? null : _approveSeller,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.close),
            label: const Text('Reject'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _isProcessing ? null : _rejectSeller,
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    
    DateTime dateTime = timestamp.toDate();
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}
