import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_theme.dart';

class PasswordRecoveryFlow extends StatefulWidget {
  final bool isChangePassword;
  const PasswordRecoveryFlow({super.key, this.isChangePassword = false});

  @override
  State<PasswordRecoveryFlow> createState() => _PasswordRecoveryFlowState();
}

class _PasswordRecoveryFlowState extends State<PasswordRecoveryFlow> {
  late TextEditingController _emailCtrl;
  final _formKey = GlobalKey<FormState>();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController();
    _emailCtrl.text = FirebaseAuth.instance.currentUser?.email ?? '';
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          widget.isChangePassword ? 'Change Password' : 'Forgot Password',
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: FadeInRight(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SECURITY STEP', style: AppTheme.label.copyWith(color: AppTheme.primary, letterSpacing: 1.2)),
                const SizedBox(height: 8),
                Text(widget.isChangePassword ? 'Change Password' : 'Reset Password', style: AppTheme.h1.copyWith(fontSize: 32, color: const Color(0xFF0F172A))),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
                  child: const Text(
                    'We will send a password reset link to your email address. You can create your new password from that link.',
                    style: TextStyle(height: 1.5, color: Color(0xFF475569), fontSize: 14),
                  ),
                ),
                const SizedBox(height: 32),
                Text('Email Address', style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v!.isEmpty || !v.contains('@') ? 'Enter a valid email' : null,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.mail_outline_rounded, color: AppTheme.textHint),
                    hintText: 'alexander.hall@corporate.com',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.divider)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.divider)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _isSending ? null : () async {
                    if (_formKey.currentState!.validate()) {
                      setState(() => _isSending = true);
                      final email = _emailCtrl.text.trim();
                      try {
                        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Password reset link sent to your email!'),
                              backgroundColor: AppTheme.success,
                              duration: Duration(seconds: 4),
                            ),
                          );
                          Navigator.maybePop(context); // Return back safely
                        }
                      } on FirebaseAuthException catch (e) {
                        if (mounted) {
                          String msg = 'Failed to send reset link.';
                          if (e.code == 'user-not-found') msg = 'No user found with this email.';
                          if (e.code == 'invalid-email') msg = 'Invalid email address.';
                          ScaffoldMessenger.of(context).showSnackBar(
                             SnackBar(content: Text(msg), backgroundColor: AppTheme.danger)
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                             SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger)
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _isSending = false);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isSending 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Send Reset Link', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      SizedBox(width: 8),
                      Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Center(child: Text('SECURE PROTOCOL 2.4', style: AppTheme.label.copyWith(color: AppTheme.textHint, fontSize: 10))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
