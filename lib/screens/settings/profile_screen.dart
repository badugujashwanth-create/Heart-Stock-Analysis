import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../utils/ui.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _nameController.text = await AuthService.instance.getUserName();
    _emailController.text = await AuthService.instance.getUserEmail();
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    await AuthService.instance.updateProfile(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(controller: _nameController, decoration: inputDecoration(context).copyWith(labelText: 'Full Name')),
                  const SizedBox(height: 12),
                  TextField(controller: _emailController, decoration: inputDecoration(context).copyWith(labelText: 'Email')),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                  child: Text(
                    'Save',
                    style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                  ),
                )
              ],
            ),
          ),
    );
  }
}
