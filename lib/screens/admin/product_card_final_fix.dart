import 'package:flutter/material.dart';
import './product_approval_screen_consolidated.dart';

class ProductCardFinalFix {
  static Widget buildProductCard(
      BuildContext context,
      Map<String, dynamic> product,
      Function(String) approveProduct,
      Function(String) rejectProduct,
      Function(int) loadProductsByTab,
      TabController tabController) {
    
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
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image with fixed height
          SizedBox(
            height: 90, // Fixed smaller height
            width: double.infinity,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: SizedBox(
                    width: double.infinity,
                    height: 90,
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
                ),
                Positioned(
                  top: 5,
                  right: 5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Product Info - compact fixed height
          Container(
            padding: const EdgeInsets.fromLTRB(5.0, 2.0, 5.0, 0),
            height: 25, // Fixed height
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
                    const Text('•', style: TextStyle(color: Colors.grey, fontSize: 7)),
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
          
          // Spacer to push buttons to the bottom part
          const Spacer(),
          
          // Action Buttons - compact fixed height at the bottom
          Container(
            padding: const EdgeInsets.only(bottom: 4, left: 4, right: 4),
            child: status == 'pending'
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Row with view and approve
                    Row(
                      children: [
                        SizedBox(
                          width: 30,
                          height: 22,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            iconSize: 14,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.visibility, color: Colors.blue),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProductApprovalScreenNew(productId: product['id']),
                                ),
                              ).then((_) => loadProductsByTab(tabController.index));
                            },
                          ),
                        ),
                        
                        Expanded(
                          child: SizedBox(
                            height: 22,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () => approveProduct(product['id']),
                              child: const Text('Approve', style: TextStyle(fontSize: 9)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 2),
                    
                    // Reject button
                    SizedBox(
                      width: double.infinity,
                      height: 22,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => rejectProduct(product['id']),
                        child: const Text('Reject', style: TextStyle(fontSize: 9)),
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(maxWidth: 30, maxHeight: 30),
                      visualDensity: VisualDensity.compact,
                      iconSize: 16,
                      icon: const Icon(Icons.visibility, color: Colors.blue),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProductApprovalScreenNew(productId: product['id']),
                          ),
                        ).then((_) => loadProductsByTab(tabController.index));
                      },
                    ),
                    if (status == 'rejected')
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(maxWidth: 30, maxHeight: 30),
                        visualDensity: VisualDensity.compact,
                        iconSize: 16,
                        icon: const Icon(Icons.check_circle, color: Colors.green),
                        onPressed: () => approveProduct(product['id']),
                      ),
                    if (status == 'approved')
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(maxWidth: 30, maxHeight: 30),
                        visualDensity: VisualDensity.compact,
                        iconSize: 16,
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        onPressed: () => rejectProduct(product['id']),
                      ),
                  ],
                ),
          ),
        ],
      ),
    );
  }
}
