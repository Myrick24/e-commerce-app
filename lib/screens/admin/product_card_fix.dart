import 'package:flutter/material.dart';
import './product_approval_screen_consolidated.dart';

// A utility class to help fix the overflow issue in the product listings
class ProductCardFix {
  static Widget buildFixedCard(
      Map<String, dynamic> product,
      String Function(String) getStatus,
      Function(String) approveProduct,
      Function(String) rejectProduct,
      TabController tabController,
      Function(int) loadProductsByTab) {
    
    String status = product['status'] ?? 'pending';
    Color statusColor;
    
    switch (status.toLowerCase()) {
      case 'approved':
        statusColor = Colors.green;
        break;
      case 'rejected':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.orange;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image - reduced height
          Container(
            height: 90, // Fixed smaller height
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    child: product['imageUrl'] != null
                        ? Image.network(
                            product['imageUrl'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey.shade200,
                                child: const Icon(
                                  Icons.image_not_supported,
                                  color: Colors.grey,
                                  size: 30,
                                ),
                              );
                            },
                          )
                        : Container(
                            color: Colors.grey.shade200,
                            child: const Icon(
                              Icons.image,
                              color: Colors.grey,
                              size: 30,
                            ),
                          ),
                  ),
                  Positioned(
                    top: 5,
                    right: 5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Product Info - ultra-compact
          Container(
            padding: const EdgeInsets.fromLTRB(5.0, 2.0, 5.0, 0),
            height: 30, // Fixed height
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  product['name'] ?? 'Unnamed Product',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    height: 1.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                
                // Price and seller
                Row(
                  children: [
                    Text(
                      '\$${product['price']?.toString() ?? '0.00'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 9,
                        height: 1.0,
                        color: Colors.green,
                      ),
                    ),
                    Text('•', style: TextStyle(color: Colors.grey, fontSize: 7)),
                    Expanded(
                      child: Text(
                        '${product['sellerName'] ?? 'Unknown'}',
                        style: const TextStyle(
                          fontSize: 8,
                          height: 1.0,
                          color: Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Action Buttons - fixed height container
          Expanded(
            child: status == 'pending'
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 0.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Row with view and approve
                      Row(
                        children: [
                          IconButton(
                            constraints: const BoxConstraints(maxHeight: 20),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            iconSize: 14,
                            icon: const Icon(Icons.visibility, color: Colors.blue),
                            onPressed: () {
                              Navigator.push(
                                product['context'],
                                MaterialPageRoute(
                                  builder: (context) => ProductApprovalScreenNew(productId: product['id']),
                                ),
                              ).then((_) => loadProductsByTab(tabController.index));
                            },
                          ),
                          
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 20),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () => approveProduct(product['id']),
                              child: const Text('Approve', style: TextStyle(fontSize: 9)),
                            ),
                          ),
                        ],
                      ),
                      
                      // Reject button
                      SizedBox(
                        width: double.infinity,
                        height: 20,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 20),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () => rejectProduct(product['id']),
                          child: const Text('Reject', style: TextStyle(fontSize: 9)),
                        ),
                      ),
                    ],
                  ),
                )
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        iconSize: 14,
                        constraints: const BoxConstraints(maxHeight: 20),
                        icon: const Icon(Icons.visibility, color: Colors.blue),
                        onPressed: () {
                          Navigator.push(
                            product['context'],
                            MaterialPageRoute(
                              builder: (context) => ProductApprovalScreenNew(productId: product['id']),
                            ),
                          ).then((_) => loadProductsByTab(tabController.index));
                        },
                        padding: EdgeInsets.zero,
                      ),
                      if (status == 'rejected')
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          iconSize: 14,
                          constraints: const BoxConstraints(maxHeight: 20),
                          icon: const Icon(Icons.check_circle, color: Colors.green),
                          onPressed: () => approveProduct(product['id']),
                          padding: EdgeInsets.zero,
                        ),
                      if (status == 'approved')
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          iconSize: 14,
                          constraints: const BoxConstraints(maxHeight: 20),
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          onPressed: () => rejectProduct(product['id']),
                          padding: EdgeInsets.zero,
                        ),
                    ],
                  ),
                ),
          ),
        ],
      ),
    );
  }
}
