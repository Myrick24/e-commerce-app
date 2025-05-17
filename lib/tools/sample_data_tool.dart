import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'sample_data_generator.dart';

class SampleDataTool extends StatefulWidget {
  const SampleDataTool({Key? key}) : super(key: key);

  @override
  State<SampleDataTool> createState() => _SampleDataToolState();
}

class _SampleDataToolState extends State<SampleDataTool> {
  final _passwordController = TextEditingController(text: 'Password123!');
  final _generator = SampleDataGenerator();
  bool _isLoading = false;
  String _message = '';
  bool _success = false;
  Map<String, List<String>> _results = {};
  
  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }
  
  Future<void> _generateSampleData() async {
    if (_passwordController.text.isEmpty) {
      setState(() {
        _message = 'Please enter a password for sample user accounts';
        _success = false;
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _message = 'Generating sample data...';
    });
    
    try {
      // Check if user is admin
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
          _message = 'Error: You need to be logged in as an admin to generate sample data';
          _success = false;
        });
        return;
      }
      
      // Generate all sample data
      Map<String, List<String>> results = await _generator.generateAllSampleData(
        password: _passwordController.text,
      );
      
      setState(() {
        _isLoading = false;
        _results = results;
        _message = 'Sample data generated successfully!';
        _success = true;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _message = 'Error generating sample data: ${e.toString()}';
        _success = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sample Data Generator'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Generate Sample Data',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'This tool will create sample users, products, transactions, and announcements in your Firebase project for testing purposes.',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              const Text(
                'Default password for all sample users:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter password for sample users',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _generateSampleData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Generate Sample Data'),
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
                    ),
                  ),
                ),
              ],
              
              // Display results if successful
              if (_success && _results.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'Sample Data Summary:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildResultCard('Users', _results['users'] ?? []),
                _buildResultCard('Products', _results['products'] ?? []),
                _buildResultCard('Transactions', _results['transactions'] ?? []),
                _buildResultCard('Announcements', _results['announcements'] ?? []),
                const SizedBox(height: 16),
                const Text(
                  'Note: You can now log in with any of the sample user accounts using the password you provided.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildResultCard(String title, List<String> ids) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$title (${ids.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              ids.isEmpty 
                  ? 'None created' 
                  : '${ids.length} ${title.toLowerCase()} created successfully',
            ),
          ],
        ),
      ),
    );
  }
}
