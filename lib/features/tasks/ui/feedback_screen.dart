import 'package:flutter/material.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _controller = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() {
      _submitted = true;
    });
    // In a real app, send feedback to backend or email
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send Feedback')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _submitted
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 64),
                    const SizedBox(height: 16),
                    const Text('Thank you for your feedback!', style: TextStyle(fontSize: 18)),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Your feedback helps us improve Planly.', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _controller,
                    maxLines: 5,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Type your feedback here...',
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _controller.text.trim().isEmpty ? null : _submit,
                    child: const Text('Submit'),
                  ),
                ],
              ),
      ),
    );
  }
}
