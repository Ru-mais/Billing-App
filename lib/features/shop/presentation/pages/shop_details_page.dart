import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/entities/shop.dart';
import '../bloc/shop_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_validators.dart';

class ShopDetailsPage extends StatefulWidget {
  const ShopDetailsPage({super.key});

  @override
  State<ShopDetailsPage> createState() => _ShopDetailsPageState();
}

class _ShopDetailsPageState extends State<ShopDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _address1Controller;
  late TextEditingController _address2Controller;
  late TextEditingController _phoneController;
  late TextEditingController _upiController;
  late TextEditingController _footerController;
  late TextEditingController _gstInController;
  String? _logoPath;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _address1Controller = TextEditingController();
    _address2Controller = TextEditingController();
    _phoneController = TextEditingController();
    _upiController = TextEditingController();
    _footerController = TextEditingController();
    _gstInController = TextEditingController();

    // Load shop data
    context.read<ShopBloc>().add(LoadShopEvent());
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _logoPath = image.path;
      });
    }
  }

  void _updateControllers(Shop shop) {
    if (_nameController.text.isEmpty && shop.name.isNotEmpty) {
      _nameController.text = shop.name;
      _address1Controller.text = shop.addressLine1;
      _address2Controller.text = shop.addressLine2;
      _phoneController.text = shop.phoneNumber;
      _upiController.text = shop.upiId;
      _footerController.text = shop.footerText;
      _gstInController.text = shop.gstIn;
      setState(() {
        _logoPath = shop.logoPath;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _address1Controller.dispose();
    _address2Controller.dispose();
    _phoneController.dispose();
    _upiController.dispose();
    _footerController.dispose();
    _gstInController.dispose();
    super.dispose();
  }

  void _saveShop() {
    if (_formKey.currentState!.validate()) {
      final shop = Shop(
        name: _nameController.text,
        addressLine1: _address1Controller.text,
        addressLine2: _address2Controller.text,
        phoneNumber: _phoneController.text,
        upiId: _upiController.text,
        footerText: _footerController.text,
        logoPath: _logoPath ?? '',
        gstIn: _gstInController.text,
      );

      context.read<ShopBloc>().add(UpdateShopEvent(shop));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final scaffoldBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text('Shop Details', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: BlocConsumer<ShopBloc, ShopState>(
        listener: (context, state) {
          if (state is ShopLoaded) {
            _updateControllers(state.shop);
          } else if (state is ShopOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Shop details saved!'),
                backgroundColor: Colors.green));
            context.pop();
          } else if (state is ShopError) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(state.message), backgroundColor: Colors.red));
          }
        },
        buildWhen: (previous, current) =>
            current is ShopLoading || current is ShopLoaded,
        builder: (context, state) {
          if (state is ShopLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Edit Shop Details', 
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Logo Section
                              Center(
                                child: GestureDetector(
                                  onTap: _pickImage,
                                  child: Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF334155) : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: borderColor),
                                      image: _logoPath != null && _logoPath!.isNotEmpty
                                          ? DecorationImage(
                                              image: FileImage(File(_logoPath!)),
                                              fit: BoxFit.contain,
                                            )
                                          : null,
                                    ),
                                    child: _logoPath == null || _logoPath!.isEmpty
                                        ? const Icon(Icons.add_a_photo_outlined, color: Colors.grey)
                                        : null,
                                  ),
                                ),
                              ),
                              if (_logoPath != null && _logoPath!.isNotEmpty)
                                Center(
                                  child: TextButton(
                                    onPressed: () => setState(() => _logoPath = ''),
                                    child: const Text('Remove Logo', style: TextStyle(color: Colors.red, fontSize: 12)),
                                  ),
                                ),
                              const SizedBox(height: 24),

                              _buildField('Shop Name', _nameController, 'e.g. Billo', validator: AppValidators.required('Required')),
                              _buildField('Address Line 1', _address1Controller, 'Building, street...'),
                              _buildField('Address Line 2', _address2Controller, 'City, State, ZIP'),
                              _buildField('Phone Number', _phoneController, '+91...', keyboardType: TextInputType.phone),
                              _buildField('UPI ID', _upiController, 'user@upi'),
                              _buildField('GSTIN (Optional)', _gstInController, '32AAAAA...'),
                              _buildField('Receipt Footer Text', _footerController, 'Thank you!', maxLines: 2),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Bottom Buttons
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  border: Border(top: BorderSide(color: borderColor)),
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => context.pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: borderColor),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _saveShop,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: isDark ? Colors.black : Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            elevation: 0,
                          ),
                          child: const Text('Save Details', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            ],
          );
        },
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, String hint, {
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
            filled: true,
            fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
