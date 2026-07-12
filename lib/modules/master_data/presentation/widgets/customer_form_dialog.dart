import 'package:flutter/material.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';
import 'package:phone_shop_pos/core/utils/notes_safety.dart';
import 'package:phone_shop_pos/core/validation/field_validators.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/modules/customers/domain/entities/customer_entity.dart';

class CustomerFormData {
  const CustomerFormData({
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    required this.notes,
    required this.isActive,
  });

  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;
  final bool isActive;
}

class CustomerFormDialog extends StatefulWidget {
  const CustomerFormDialog({super.key, this.initial});

  final CustomerEntity? initial;

  @override
  State<CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<CustomerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _notesController;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _phoneController = TextEditingController(text: initial?.phone ?? '');
    _emailController = TextEditingController(text: initial?.email ?? '');
    _addressController = TextEditingController(text: initial?.address ?? '');
    _notesController = TextEditingController(text: initial?.notes ?? '');
    _isActive = initial?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String? _nullIfBlank(String value) {
    return NotesSafety.normalizeNullable(value);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(context).pop(
      CustomerFormData(
        name: _nameController.text.trim(),
        phone: _nullIfBlank(_phoneController.text),
        email: _nullIfBlank(_emailController.text),
        address: _nullIfBlank(_addressController.text),
        notes: _nullIfBlank(_notesController.text),
        isActive: _isActive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initial != null;
    return AppDialogEscToClose(
      child: AlertDialog(
        title: Text(isEditing ? 'Edit Customer' : 'Add Customer'),
        content: SizedBox(
          width: 560,
          child: Form(
            key: _formKey,
            child: ListView(
              shrinkWrap: true,
              children: <Widget>[
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  decoration: appDesktopInputDecoration(
                    labelText: 'Customer Name',
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Customer name is required'
                      : null,
                ),
                AppSpacing.gapSm,
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        decoration: appDesktopInputDecoration(
                          labelText: 'Phone',
                        ),
                        validator: FieldValidators.phone,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: TextFormField(
                        controller: _emailController,
                        decoration: appDesktopInputDecoration(
                          labelText: 'Email',
                        ),
                      ),
                    ),
                  ],
                ),
                AppSpacing.gapSm,
                TextFormField(
                  controller: _addressController,
                  maxLines: 2,
                  decoration: appDesktopInputDecoration(
                    labelText: 'Address',
                  ),
                ),
                AppSpacing.gapSm,
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  maxLength: NotesSafety.maxLength,
                  decoration: appDesktopInputDecoration(
                    labelText: 'Notes',
                  ),
                  validator: (value) =>
                      NotesSafety.validate(value, fieldLabel: 'Customer notes'),
                ),
                AppSpacing.gapSm,
                SwitchListTile(
                  title: const Text('Active'),
                  value: _isActive,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _submit,
            child: Text(isEditing ? 'Save' : 'Create'),
          ),
        ],
      ),
    );
  }
}
