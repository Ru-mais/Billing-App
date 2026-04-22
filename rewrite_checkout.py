import re

with open("lib/features/billing/presentation/pages/checkout_page.dart", "r") as f:
    text = f.read()

start_str = "  @override\n  Widget build(BuildContext context) {"
# Replace from `start_str` to the end of the file.

start_idx = text.find(start_str)

new_content = """  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = Theme.of(context).dividerColor.withValues(alpha: 0.1);
    final cardBg = Theme.of(context).cardTheme.color;

    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        _cancelBill();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Checkout', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          centerTitle: false,
          automaticallyImplyLeading: false, 
        ),
        body: BlocConsumer<BillingBloc, BillingState>(
          listener: (context, state) {
            if (state.printSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Printed successfully'), backgroundColor: Colors.green)
              );
              context.read<BillingBloc>().add(ClearCartEvent());
              setState(() { _canPop = true; });
              context.pop();
            } else if (state.error != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.error!), backgroundColor: Colors.red)
              );
            }
          },
          builder: (context, billingState) {
            return BlocBuilder<ShopBloc, ShopState>(
              builder: (context, shopState) {
                String upiId = '';
                String shopName = '';
                if (shopState is ShopLoaded) {
                  upiId = shopState.shop.upiId;
                  shopName = shopState.shop.name;
                }

                return Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        children: [
                          // Card 1: Order Items
                          Container(
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: borderColor),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Order Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 12),
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: borderColor),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Column(
                                    children: [
                                      ...billingState.cartItems.map((item) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                          decoration: BoxDecoration(
                                            border: Border(bottom: BorderSide(color: borderColor)),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(item.product.name, style: Theme.of(context).textTheme.bodyMedium),
                                              Text('₹${item.total.toStringAsFixed(0)}', style: Theme.of(context).textTheme.bodyMedium),
                                            ],
                                          ),
                                        );
                                      }),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                                            Text('₹${billingState.netAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Card 2: Customer Inputs
                          Container(
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: borderColor),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                TextField(
                                  controller: _customerNameController,
                                  decoration: InputDecoration(
                                    hintText: 'Customer Name',
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: borderColor)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: borderColor)),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _customerPhoneController,
                                  keyboardType: TextInputType.phone,
                                  decoration: InputDecoration(
                                    hintText: 'Customer Phone',
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: borderColor)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: borderColor)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Card 3: Payment Method
                          Container(
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: borderColor),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () => setState(() => _selectedPaymentMethod = 'Cash'),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: _selectedPaymentMethod == 'Cash' ? const Color(0xFF0F172A) : Colors.transparent,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: _selectedPaymentMethod == 'Cash' ? const Color(0xFF0F172A) : borderColor),
                                        ),
                                        child: Text(
                                          'Cash (In Hand)',
                                          style: TextStyle(
                                            color: _selectedPaymentMethod == 'Cash' ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color,
                                            fontWeight: _selectedPaymentMethod == 'Cash' ? FontWeight.w600 : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    GestureDetector(
                                      onTap: () => setState(() => _selectedPaymentMethod = 'QR'),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: _selectedPaymentMethod == 'QR' ? const Color(0xFF0F172A) : Colors.transparent,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: _selectedPaymentMethod == 'QR' ? const Color(0xFF0F172A) : borderColor),
                                        ),
                                        child: Text(
                                          'QR',
                                          style: TextStyle(
                                            color: _selectedPaymentMethod == 'QR' ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color,
                                            fontWeight: _selectedPaymentMethod == 'QR' ? FontWeight.w600 : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_selectedPaymentMethod == 'QR' && upiId.isNotEmpty) ...[
                                  const SizedBox(height: 24),
                                  Center(
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: borderColor),
                                      ),
                                      width: 200,
                                      height: 200,
                                      child: PrettyQrView.data(
                                        data: 'upi://pay?pa=$upiId&pn=$shopName&am=${billingState.totalAmount.toStringAsFixed(2)}&cu=INR',
                                      ),
                                    ),
                                  ),
                                ]
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),

                    // Bottom Buttons
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: billingState.isPrinting ? null : _cancelBill,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF3B30),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                child: const Text('Cancel Bill', style: TextStyle(fontWeight: FontWeight.w600)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: billingState.isPrinting
                                    ? null
                                    : () {
                                        if (shopState is ShopLoaded) {
                                          context.read<BillingBloc>().add(
                                            PrintReceiptEvent(
                                                shopName: shopState.shop.name,
                                                address1: shopState.shop.addressLine1,
                                                address2: shopState.shop.addressLine2,
                                                phone: shopState.shop.phoneNumber,
                                                footer: shopState.shop.footerText,
                                                paymentMethod: _selectedPaymentMethod,
                                                gstIn: shopState.shop.gstIn,
                                                customerName: _customerNameController.text.trim(),
                                                customerPhone: _customerPhoneController.text.trim()),
                                          );
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Shop details not loaded'), backgroundColor: Colors.red),
                                          );
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F172A),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                child: billingState.isPrinting 
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text('Print Receipt', style: TextStyle(fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
"""

with open("lib/features/billing/presentation/pages/checkout_page.dart", "w") as f:
    f.write(text[:start_idx] + new_content)

