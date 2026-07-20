import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'manager_request_submitted_screen.dart';

class ManagerRequestCorrectionScreen extends StatefulWidget {
  final DateTime attendanceDate;
  final String? initialCheckIn;
  final String? initialCheckOut;

  const ManagerRequestCorrectionScreen({
    super.key,
    required this.attendanceDate,
    this.initialCheckIn,
    this.initialCheckOut,
  });

  @override
  State<ManagerRequestCorrectionScreen> createState() => _ManagerRequestCorrectionScreenState();
}

class _ManagerRequestCorrectionScreenState extends State<ManagerRequestCorrectionScreen> {
  late final TextEditingController _checkInController;
  late final TextEditingController _checkOutController;
  final _reasonController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkInController = TextEditingController(text: widget.initialCheckIn ?? '');
    _checkOutController = TextEditingController(text: widget.initialCheckOut ?? '');
  }

  @override
  void dispose() {
    _checkInController.dispose();
    _checkOutController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _selectTime(BuildContext context, TextEditingController controller) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF5C5CFF),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final now = DateTime.now();
      final dt = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
      setState(() {
        controller.text = DateFormat('hh:mm a').format(dt);
        _errorMessage = null;
      });
    }
  }

  Future<void> _submitRequest() async {
    if (_reasonController.text.trim().isEmpty) {
      setState(() => _errorMessage = "Reason is required");
      return;
    }
    
    if (_checkInController.text.isEmpty && _checkOutController.text.isEmpty) {
      setState(() => _errorMessage = "Please provide at least one correct time");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not authenticated");

      final data = {
        'userId': user.email ?? user.uid,
        'date': Timestamp.fromDate(widget.attendanceDate),
        'correctCheckInTime': _checkInController.text,
        'correctCheckOutTime': _checkOutController.text,
        'reason': _reasonController.text.trim(),
        'status': 'pending',
        'requestDate': FieldValue.serverTimestamp(),
        'managerCorrection': true,
      };

      await FirebaseFirestore.instance.collection('attendanceCorrections').add(data);
      
      if (mounted) {
        final dateStr = DateFormat('E, d MMM yyyy').format(widget.attendanceDate);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ManagerRequestSubmittedScreen(dateString: dateStr)),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to submit request: $e";
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1F2937)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Request Correction',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Color(0xFF5C5CFF), size: 20),
            onPressed: () {},
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE5E7EB), height: 1),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel('Attendance Date'),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB), // Read only look
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF3F4F6)),
                ),
                child: Text(
                  DateFormat('E, d MMM yyyy').format(widget.attendanceDate),
                  style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
                ),
              ),
              const SizedBox(height: 20),
              
              _buildLabel('Correct Check-In Time'),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _selectTime(context, _checkInController),
                child: AbsorbPointer(
                  child: TextField(
                    controller: _checkInController,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
                    decoration: InputDecoration(
                      hintText: 'e.g. 09:00 AM',
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF5C5CFF)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              _buildLabel('Correct Check-Out Time'),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _selectTime(context, _checkOutController),
                child: AbsorbPointer(
                  child: TextField(
                    controller: _checkOutController,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
                    decoration: InputDecoration(
                      hintText: 'e.g. 06:00 PM',
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF5C5CFF)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              _buildLabel('Reason'),
              const SizedBox(height: 8),
              TextField(
                controller: _reasonController,
                maxLines: 4,
                style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
                decoration: InputDecoration(
                  hintText: 'Describe the reason for correction...',
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  contentPadding: const EdgeInsets.all(16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF5C5CFF)),
                  ),
                ),
                onChanged: (_) {
                  if (_errorMessage != null) setState(() => _errorMessage = null);
                },
              ),
              const SizedBox(height: 20),
              
              // Attachment button (UI only as per instructions, matching image 2)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.download_rounded, color: Color(0xFF9CA3AF), size: 20),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Attachment (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
                        SizedBox(height: 2),
                        Text('Upload supporting document', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF3F4F6),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5C5CFF),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading 
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Submit Request', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ],
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF4B5563)),
    );
  }
}
