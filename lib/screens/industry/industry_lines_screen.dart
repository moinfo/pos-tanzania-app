import 'package:flutter/material.dart';
import '../../services/industry_service.dart';
import '../../models/industry.dart';
import '../../utils/constants.dart';

/// Lines / Timu (Uzalishaji production lines) - read-only, groups casual
/// labourers and machines by Production Line with today's attendance and
/// output. No JSON endpoint exists; scraped from the Industry page
/// (IndustryService.getLines) matching application/views/industry/lines.php.
class IndustryLinesScreen extends StatefulWidget {
  final IndustryService service;
  final VoidCallback onSessionExpired;

  const IndustryLinesScreen({
    super.key,
    required this.service,
    required this.onSessionExpired,
  });

  @override
  State<IndustryLinesScreen> createState() => _IndustryLinesScreenState();
}

class _IndustryLinesScreenState extends State<IndustryLinesScreen> {
  List<ProductionLineGroup> _groups = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await widget.service.getLines();

    if (!mounted) return;

    if (response.statusCode == 440) {
      setState(() => _isLoading = false);
      widget.onSessionExpired();
      return;
    }

    if (response.isSuccess && response.data != null) {
      setState(() {
        _groups = response.data!;
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = response.message;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: industryScrollPadding(context),
        children: [
          Text('Timu ya Uzalishaji (Steel Wire) kwa Line',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.brandPrimary)),
          const SizedBox(height: 4),
          Text(
            'Wafanyakazi na Mashine ya kila Line, waliopo kazini leo, na uzalishaji wa leo (PC). '
            'Unaweza kubadilisha Line ya mtu/mashine kwenye Settings.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          if (_groups.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('No production lines configured.')),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900 ? 3 : (constraints.maxWidth >= 600 ? 2 : 1);
                final cardWidth = (constraints.maxWidth - (columns - 1) * 12) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _groups
                      .map((g) => SizedBox(width: cardWidth, child: _buildGroupCard(g)))
                      .toList(),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(ProductionLineGroup group) {
    final muted = group.isUnassigned;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                Icon(muted ? Icons.help_outline : Icons.grid_view,
                    size: 16, color: muted ? Colors.grey.shade600 : AppColors.brandPrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    group.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: muted ? Colors.grey.shade600 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!group.isUnassigned) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _stat('${group.presentCount}/${group.labourers.length}', 'Wapo Leo'),
                      _stat('${group.machineNames.length}', 'Mashine'),
                      _stat('${group.producedToday}', 'PC Leo'),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
                const Text('Wafanyakazi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                if (group.labourers.isEmpty)
                  Text('Hakuna mfanyakazi kwenye Line hii',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13))
                else
                  ...group.labourers.map((l) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Icon(
                              l.present ? Icons.check_circle : Icons.remove_circle_outline,
                              size: 14,
                              color: l.present ? Colors.green : Colors.grey.shade400,
                            ),
                            const SizedBox(width: 6),
                            Expanded(child: Text(l.name, style: const TextStyle(fontSize: 13))),
                          ],
                        ),
                      )),
                const SizedBox(height: 10),
                const Text('Mashine', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                if (group.machineNames.isEmpty)
                  Text('Hakuna mashine kwenye Line hii',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13))
                else
                  ...group.machineNames.map((m) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Icon(Icons.settings, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 6),
                            Expanded(child: Text(m, style: const TextStyle(fontSize: 13))),
                          ],
                        ),
                      )),
                if (group.isUnassigned) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Hawa bado hawajapewa Line -- nenda Settings kuwapangia.',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }
}
