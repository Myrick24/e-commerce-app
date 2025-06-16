import 'package:flutter/material.dart';
import '../tools/manual_admin_restore.dart';

class TempAdminRestorePage extends StatefulWidget {
  @override
  _TempAdminRestorePageState createState() => _TempAdminRestorePageState();
}

class _TempAdminRestorePageState extends State<TempAdminRestorePage> {
  String _result = '';
  bool _isLoading = false;

  Future<void> _restoreAdmin() async {
    setState(() {
      _isLoading = true;
      _result = 'Restoring admin account...';
    });

    String result = await ManualAdminRestore.restoreAdminAccount();
    
    setState(() {
      _isLoading = false;
      _result = result;
    });
  }

  Future<void> _checkCurrentUser() async {
    setState(() {
      _isLoading = true;
      _result = 'Checking current user...';
    });

    String result = await ManualAdminRestore.getCurrentAdminInfo();
    
    setState(() {
      _isLoading = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Restore Tool'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _isLoading ? null : _checkCurrentUser,
              child: Text('Check Current User Status'),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _restoreAdmin,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: Text('Restore Admin Account'),
            ),
            SizedBox(height: 24),
            if (_result.isNotEmpty) ...[
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _result,
                  style: TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ],
            if (_isLoading) ...[
              SizedBox(height: 16),
              Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}
