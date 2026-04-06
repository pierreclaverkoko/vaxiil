import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/features/business/data/organization_models.dart';
import 'package:vaxiil_mobile/features/business/data/organization_repository.dart';
import 'package:vaxiil_mobile/shared/widgets/soft_card.dart';

class BusinessSettingsPage extends StatefulWidget {
  const BusinessSettingsPage({required this.organizationId, super.key});

  final String organizationId;

  @override
  State<BusinessSettingsPage> createState() => _BusinessSettingsPageState();
}

class _BusinessSettingsPageState extends State<BusinessSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _description = TextEditingController();
  final _website = TextEditingController();

  Object? _loadError;
  var _loading = true;
  var _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final o = await sl<OrganizationRepository>().getById(widget.organizationId);
      if (!mounted) return;
      _applyFromOrg(o);
      setState(() {
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _loading = false;
      });
    }
  }

  void _applyFromOrg(OrganizationModel o) {
    _name.text = o.name;
    _phone.text = o.phone ?? '';
    _description.text = o.description ?? '';
    _website.text = o.website ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _description.dispose();
    _website.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await sl<OrganizationRepository>().update(
        widget.organizationId,
        name: _name.text.trim(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        website: _website.text.trim().isEmpty ? null : _website.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved')),
      );
      context.pop();
    } catch (e) {
      final msg = e is Failure ? e.message : e.toString();
      if (mounted) setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Business settings'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _loadError is Failure
                          ? (_loadError! as Failure).message
                          : _loadError.toString(),
                    ),
                  ),
                )
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      SoftCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Organization details',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _name,
                              decoration: const InputDecoration(
                                labelText: 'Name',
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Required'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _phone,
                              decoration: const InputDecoration(
                                labelText: 'Phone',
                              ),
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _description,
                              decoration: const InputDecoration(
                                labelText: 'Description',
                              ),
                              maxLines: 3,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _website,
                              decoration: const InputDecoration(
                                labelText: 'Website',
                              ),
                              keyboardType: TextInputType.url,
                            ),
                          ],
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Save'),
                      ),
                    ],
                  ),
                ),
    );
  }
}
