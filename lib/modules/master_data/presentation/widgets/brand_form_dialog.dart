import 'package:flutter/material.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/brand_entity.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';

class BrandFormData {
  const BrandFormData({required this.name, required this.isActive});

  final String name;
  final bool isActive;
}

class BrandFormDialog extends StatefulWidget {
  const BrandFormDialog({super.key, this.initial});

  final BrandEntity? initial;

  @override
  State<BrandFormDialog> createState() => _BrandFormDialogState();
}

class _BrandFormDialogState extends State<BrandFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initial?.name ?? '');
    _isActive = widget.initial?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(context).pop(
      BrandFormData(name: _nameController.text.trim(), isActive: _isActive),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initial != null;
    return AlertDialog(
      title: Text(isEditing ? 'Edit Brand' : 'Add Brand'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                controller: _nameController,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: 'Brand Name',
                  isDense: true,
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Brand name is required'
                    : null,
              ),
              const SizedBox(height: AppSpacing.sm),
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
    );
  }
}
