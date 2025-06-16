import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RestoreAdminTool extends StatefulWidget {
  const RestoreAdminTool({Key? key}) : super(key: key);

  @override
  State<RestoreAdminTool> createState() => _RestoreAdminToolState();
}

class _RestoreAdminToolState extends State<RestoreAdminTool> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool _isLoading = false;
  String _message = '';
  bool _success = false;

  Future<void> _restoreAdminAccount() async {
    setState(() {
      _isLoading = true;
      _message = 'Restoring admin account...';
    });

    try {
      // First, try to sign in with the admin credentials to verify the account exists
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: 'admin@gmail.com',
        password: 'admin123',
      );

      User? user = userCredential.user;
      if (user != null) {
        // Check if user document already exists
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
        
        if (userDoc.exists) {
          setState(() {
            _isLoading = false;
            _message = 'Admin account already exists in users collection!\nUID: ${user.uid}';
            _success = true;
          });
          return;
        }

        // Create the admin user document in Firestore
        await _firestore.collection('users').doc(user.uid).set({
          'name': 'Admin',
          'email': 'admin@gmail.com',
          'role': 'admin',
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
          'isMainAdmin': true, // Flag to identify the main admin
        });

        setState(() {
          _isLoading = false;
          _message = 'Admin account successfully restored!\nUID: ${user.uid}\nEmail: admin@gmail.com\nRole: admin';
          _success = true;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _message = 'Error: ${e.toString()}';
        _success = false;
      });
    }
  }

  Future<void> _checkAdminStatus() async {
    setState(() {
      _isLoading = true;
      _message = 'Checking admin account status...';
    });

    try {
      // Get current user if signed in
      User? currentUser = _auth.currentUser;
      
      if (currentUser == null) {
        setState(() {
          _isLoading = false;
          _message = 'No user currently signed in. Please use the "Restore Admin Account" button to sign in and restore.';
          _success = false;
        });
        return;
      }

      // Check if current user is admin
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      
      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        String role = userData['role'] ?? 'buyer';
        String email = userData['email'] ?? 'No email';
        
        setState(() {
          _isLoading = false;
          _message = 'Current user info:\nUID: ${currentUser.uid}\nEmail: $email\nRole: $role\nDocument exists: Yes';
          _success = role == 'admin';
        });
      } else {
        setState(() {
          _isLoading = false;
          _message = 'Current user info:\nUID: ${currentUser.uid}\nEmail: ${currentUser.email}\nFirestore document: NOT FOUND\n\nUse "Restore Admin Account" to create the missing document.';
          _success = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _message = 'Error checking status: ${e.toString()}';
        _success = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restore Admin Account'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Admin Account Recovery Tool',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'This tool will restore your admin account (admin@gmail.com) in the Firestore users collection.',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Check current status button
              ElevatedButton(
                onPressed: _isLoading ? null : _checkAdminStatus,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Check Current Account Status'),
              ),
              
              const SizedBox(height: 16),
              
              // Restore admin account button
              ElevatedButton(
                onPressed: _isLoading ? null : _restoreAdminAccount,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Restore Admin Account'),
              ),
              
              if (_message.isNotEmpty) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _success ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _success ? Colors.green : Colors.red,
                    ),
                  ),
                  child: Text(
                    _message,
                    style: TextStyle(
                      color: _success ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 24),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Instructions:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      SizedBox(height: 8),
                      Text('1. Click "Check Current Account Status" to see your current login status.'),
                      SizedBox(height: 4),
                      Text('2. Click "Restore Admin Account" to sign in with admin credentials and create the missing Firestore document.'),
                      SizedBox(height: 4),
                      Text('3. After restoration, you can log in normally with admin@gmail.com and password admin123.'),
                      SizedBox(height: 8),
                      Text(
                        'Note: This will sign you in as admin and create the missing user document in Firestore.',
                        style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
