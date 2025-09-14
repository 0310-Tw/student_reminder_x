import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:students_reminder/src/services/auth_service.dart';

class SuspensionCheck extends StatelessWidget {
  final Widget child;
  final bool restrictWriteAccess;

  const SuspensionCheck({
    super.key,
    required this.child,
    this.restrictWriteAccess = false,
  });

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    if (user == null) return child;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return child;

        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        final isSuspended = userData?['status'] == 'suspended';
        final isFlagged = userData?['flagged'] == true;

        // Show notification banners for flagged/suspended users
        if (isSuspended || (isFlagged && restrictWriteAccess)) {
          return Column(
            children: [
              // Suspension/Flag notification banner
              if (isSuspended) _buildSuspensionBanner(userData),
              if (isFlagged && !isSuspended) _buildFlagBanner(userData),

              // If suspended and restrictWriteAccess is true, show read-only mode
              if (isSuspended && restrictWriteAccess)
                Expanded(child: _buildReadOnlyMode(userData))
              else
                Expanded(child: child),
            ],
          );
        }

        return child;
      },
    );
  }

  Widget _buildSuspensionBanner(Map<String, dynamic>? userData) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFD32F2F), Color(0xFFB71C1C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.block, color: Colors.white, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Account Suspended',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            userData?['suspensionReason'] ??
                'Your account has been suspended by an administrator.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'You are currently in read-only mode. Contact support if you believe this is an error.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlagBanner(Map<String, dynamic>? userData) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF9800), Color(0xFFF57700)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.flag, color: Colors.white, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account Flagged',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (userData?['flagReason'] != null)
                  Text(
                    userData!['flagReason'],
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyMode(Map<String, dynamic>? userData) {
    return Container(
      color: Color(0xFFF5F5F5),
      child: Center(
        child: Container(
          margin: EdgeInsets.all(32),
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.preview, size: 48, color: Color(0xFFD32F2F)),
              ),
              SizedBox(height: 24),
              Text(
                'Read-Only Mode',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E3440),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Your account is currently suspended. You can view content but cannot post, comment, or interact.',
                style: TextStyle(fontSize: 16, color: Color(0xFF6C7B7F)),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xFFE0E0E0)),
                ),
                child: Text(
                  'Reason: ${userData?['suspensionReason'] ?? 'No reason provided'}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF2E3440),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  // You can implement a contact support feature here
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF3498DB),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: Icon(Icons.support_agent),
                label: Text('Contact Support'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
