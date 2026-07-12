import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phone_shop_pos/core/notifications/app_notifier.dart';
import 'package:phone_shop_pos/core/theme/app_semantic_colors.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';
import 'package:phone_shop_pos/core/utils/debouncer.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/imei_trace_entity.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/pending_imei_provider.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/sales_repository_provider.dart';

class ImeiSearchTab extends ConsumerStatefulWidget {
  const ImeiSearchTab({super.key});

  @override
  ConsumerState<ImeiSearchTab> createState() => _ImeiSearchTabState();
}

class _ImeiSearchTabState extends ConsumerState<ImeiSearchTab> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final _debounce = Debouncer();
  bool _isLoading = false;
  ImeiTraceEntity? _result;
  bool _searched = false;
  String? _errorMessage;

  @override
  void dispose() {
    _debounce.dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _search(String raw) async {
    final imei = raw.trim();
    if (imei.isEmpty) {
      setState(() {
        _result = null;
        _searched = false;
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final repo = await ref.read(salesRepositoryProvider.future);
    if (!mounted) return;
    final result = await repo.getImeiTrace(imei);
    if (!mounted) return;

    result.fold(
      onSuccess: (trace) {
        setState(() {
          _isLoading = false;
          _result = trace;
          _searched = true;
        });
      },
      onFailure: (error) {
        setState(() {
          _isLoading = false;
          _result = null;
          _searched = true;
          _errorMessage = error.message;
        });
      },
    );
  }

  void _onChanged(String value) {
    _debounce.cancel();
    if (value.trim().isEmpty) {
      _search('');
      return;
    }
    _debounce.run(() => _search(value));
  }

  void _sellThis(ImeiTraceEntity trace) {
    if (trace.stockStatus != 'in_stock') {
      AppNotifier.warning(
        'This IMEI is not available for sale (status: ${trace.stockStatus}).',
      );
      return;
    }
    ref.read(pendingImeiAutoAddProvider.notifier).state = trace.imei1;
    context.go('/sales');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SearchBar(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: _onChanged,
          onSubmitted: _search,
          onClear: () {
            _controller.clear();
            _search('');
          },
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? _ErrorView(
                      message: _errorMessage!,
                      onRetry: () => _search(_controller.text),
                    )
                  : !_searched
                      ? _EmptyHint()
                      : _result == null
                          ? _NotFoundView(imei: _controller.text.trim())
                          : _ResultCard(
                              trace: _result!,
                              onSellThis: () => _sellThis(_result!),
                            ),
        ),
      ],
    );
  }
}

// ── Search bar ────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: true,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Scan or enter IMEI number…',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (_, value, __) => value.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: 'Clear',
                  onPressed: onClear,
                )
              : const SizedBox.shrink(),
        ),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}

// ── Placeholder states ─────────────────────────────────────────────────────────

class _EmptyHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.phonelink_setup_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            'Scan or type an IMEI to look up its full history.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }
}

class _NotFoundView extends StatelessWidget {
  const _NotFoundView({required this.imei});
  final String imei;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.search_off,
              size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            'No record found for IMEI: $imei',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(message),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ── Result card ────────────────────────────────────────────────────────────────

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.trace, required this.onSellThis});
  final ImeiTraceEntity trace;
  final VoidCallback onSellThis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.semantic;
    final isInStock = trace.stockStatus == 'in_stock';

    final content = Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
              // ── Header ──────────────────────────────────────────────────
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          trace.productName,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (trace.brandName.isNotEmpty &&
                            trace.brandName != '-')
                          Text(
                            trace.brandName,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  _StatusChip(status: trace.stockStatus),
                ],
              ),
              const Divider(height: 24),

              // ── IMEI row ────────────────────────────────────────────────
              _SectionTitle('IMEI Details'),
              const SizedBox(height: 8),
              _InfoRow(label: 'IMEI 1', value: trace.imei1),
              if (trace.imei2 != null)
                _InfoRow(label: 'IMEI 2', value: trace.imei2!),
              const SizedBox(height: 16),

              // ── Purchase info ────────────────────────────────────────────
              _SectionTitle('Purchase Information'),
              const SizedBox(height: 8),
              _InfoRow(
                label: 'Purchase Date',
                value: trace.purchaseDate != null
                    ? FormattingHelpers.dateYmd(trace.purchaseDate!)
                    : '-',
              ),
              _InfoRow(
                label: 'Purchase Price',
                value: FormattingHelpers.currencyPkr(trace.costPrice),
              ),
              _InfoRow(
                label: 'Supplier',
                value: trace.supplierName ?? '-',
              ),
              _InfoRow(
                label: 'Warranty',
                value: trace.remainingWarranty ?? '-',
              ),
              const SizedBox(height: 16),

              // ── Sale info ─────────────────────────────────────────────────
              _SectionTitle('Sale Information'),
              const SizedBox(height: 8),
              if (trace.isSold) ...<Widget>[
                _InfoRow(
                  label: 'Sale Date',
                  value: FormattingHelpers.dateYmd(trace.saleDate!),
                ),
                _InfoRow(
                  label: 'Sale Price',
                  value: trace.salePrice != null
                      ? FormattingHelpers.currencyPkr(trace.salePrice!)
                      : '-',
                ),
                _InfoRow(
                  label: 'Invoice',
                  value: trace.invoiceNumber ?? '-',
                ),
                _InfoRow(
                  label: 'Customer',
                  value: trace.customerName ?? 'Walk-in',
                ),
                if (trace.customerPhone != null)
                  _InfoRow(
                    label: 'Customer Phone',
                    value: trace.customerPhone!,
                  ),
                if (trace.profit != null)
                  _InfoRow(
                    label: 'Profit',
                    value: FormattingHelpers.currencyPkr(trace.profit!),
                  ),
              ] else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Not yet sold.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: semantic.success,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // ── Action ────────────────────────────────────────────────────
              if (isInStock)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onSellThis,
                    icon: const Icon(Icons.point_of_sale),
                    label: const Text('Sell This Phone'),
                  ),
                ),
        ],
      ),
    );

    return SingleChildScrollView(
      child: Card(
        clipBehavior: Clip.antiAlias,
        // The whole card is clickable when the unit is in stock, so a
        // salesman can go from search result straight into the sale with a
        // single click — no second search needed, per the sale-screen
        // hand-off requirement.
        child: isInStock
            ? InkWell(onTap: onSellThis, child: content)
            : content,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.semantic;
    final Color color;
    final String label;
    switch (status) {
      case 'in_stock':
        color = semantic.success;
        label = 'In Stock';
      case 'sold':
        color = semantic.info;
        label = 'Sold';
      case 'reserved':
        color = semantic.warning;
        label = 'Reserved';
      case 'with_dealer':
        color = semantic.warning;
        label = 'With Dealer';
      case 'returned':
        color = semantic.warning;
        label = 'Returned';
      case 'damaged':
        color = semantic.danger;
        label = 'Damaged';
      default:
        color = theme.colorScheme.outline;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
