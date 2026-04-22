import re

with open("lib/features/billing/presentation/pages/home_page.dart", "r") as f:
    text = f.read()

start_str = "  @override\n  Widget build(BuildContext context) {"
end_str = "  Widget _buildTopCard(BuildContext context) {"

start_idx = text.find(start_str)
end_idx = text.find(end_str)

new_content = """  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing App', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(
              _isCameraOn ? Icons.videocam : Icons.videocam_off,
              color: _isCameraOn ? Theme.of(context).primaryColor : null,
            ),
            onPressed: () {
              setState(() {
                _isCameraOn = !_isCameraOn;
                if (_isCameraOn) {
                  _scannerController.start();
                } else {
                  _scannerController.stop();
                }
              });
            },
            style: IconButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
            style: IconButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Theme.of(context).brightness == Brightness.dark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => context.read<ThemeBloc>().add(ToggleTheme()),
            style: IconButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Row(
            children: [
              Text('Dark', style: Theme.of(context).textTheme.bodyMedium),
              BlocBuilder<ThemeBloc, ThemeState>(
                builder: (context, state) {
                  return Switch(
                    value: state.themeMode == ThemeMode.dark,
                    onChanged: (_) => context.read<ThemeBloc>().add(ToggleTheme()),
                  );
                },
              ),
            ],
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: BlocListener<BillingBloc, BillingState>(
        listenWhen: (previous, current) =>
            (previous.error != current.error && current.error != null) ||
            (previous.pendingSizeProduct != current.pendingSizeProduct &&
                current.pendingSizeProduct != null),
        listener: (context, state) {
          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error!), backgroundColor: Colors.red),
            );
          }
          if (state.pendingSizeProduct != null) {
            _showSizePicker(context, state.pendingSizeProduct!);
          }
        },
        child: Column(
          children: [
            if (_isCameraOn)
              Container(
                height: MediaQuery.of(context).size.height * 0.35,
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                child: _buildScannerSection(),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    _buildTopCard(context),
                    const SizedBox(height: 16),
                    Expanded(child: _buildProductsCard(context)),
                    const SizedBox(height: 16),
                    _buildBottomCard(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

"""

new_file_content = text[:start_idx] + new_content + text[end_idx:]

with open("lib/features/billing/presentation/pages/home_page.dart", "w") as f:
    f.write(new_file_content)

