import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/lodge.dart';
import '../../models/permission_model.dart';
import '../../providers/permission_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import 'lodge_maintenance_screen.dart';
import 'lodge_theme.dart';

/// `GET lodge/rooms` + add/edit/delete + status change + maintenance --
/// README 3.10.
class LodgeRoomsScreen extends StatefulWidget {
  const LodgeRoomsScreen({super.key});

  @override
  State<LodgeRoomsScreen> createState() => _LodgeRoomsScreenState();
}

class _LodgeRoomsScreenState extends State<LodgeRoomsScreen> {
  final ApiService _apiService = ApiService();
  List<LodgeRoom> _rooms = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final response = await _apiService.getLodgeRooms();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (response.isSuccess && response.data != null) {
        _rooms = response.data!;
      } else {
        _errorMessage = response.message;
      }
    });
  }

  Future<void> _changeStatus(LodgeRoom room) async {
    final status = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check_circle_outline, color: AppColors.success),
              title: const Text('Vacant'),
              onTap: () => Navigator.pop(ctx, 'vacant'),
            ),
            ListTile(
              leading: const Icon(Icons.cleaning_services_outlined, color: AppColors.info),
              title: const Text('Cleaning'),
              onTap: () => Navigator.pop(ctx, 'cleaning'),
            ),
            ListTile(
              leading: const Icon(Icons.build_outlined, color: Colors.grey),
              title: const Text('Maintenance'),
              onTap: () => Navigator.pop(ctx, 'maintenance'),
            ),
          ],
        ),
      ),
    );
    if (status == null) return;

    final response = await _apiService.setLodgeRoomStatus(roomId: room.roomId, status: status);
    if (!mounted) return;
    if (response.isSuccess) {
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.message), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _deleteRoom(LodgeRoom room) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete room'),
        content: Text('Delete room ${room.roomNumber}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final response = await _apiService.deleteLodgeRoom(room.roomId);
    if (!mounted) return;
    if (response.isSuccess) {
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.message), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _showRoomFormSheet({LodgeRoom? existing}) async {
    final numberController = TextEditingController(text: existing?.roomNumber ?? '');
    final typeController = TextEditingController(text: existing?.roomType ?? '');
    final rateController = TextEditingController(text: existing != null ? existing.rate.toStringAsFixed(0) : '');
    final occupantController = TextEditingController(text: existing?.occupant ?? '');
    final descriptionController = TextEditingController(text: existing?.description ?? '');
    String purpose = existing?.purpose ?? 'guest';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            top: 18,
            bottom: MediaQuery.of(context).viewInsets.bottom + 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(existing == null ? 'New Room' : 'Edit Room',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              TextField(
                controller: numberController,
                decoration: const InputDecoration(labelText: 'Room number *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: typeController,
                decoration: const InputDecoration(labelText: 'Room type', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: purpose,
                decoration: const InputDecoration(labelText: 'Use', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'guest', child: Text('Guests (for sale)')),
                  DropdownMenuItem(value: 'staff', child: Text('Staff')),
                  DropdownMenuItem(value: 'office', child: Text('Office')),
                ],
                onChanged: (v) => setSheetState(() => purpose = v ?? purpose),
              ),
              const SizedBox(height: 10),
              if (purpose == 'guest')
                TextField(
                  controller: rateController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Rate per night', border: OutlineInputBorder()),
                )
              else
                TextField(
                  controller: occupantController,
                  decoration: const InputDecoration(labelText: 'Occupant name', border: OutlineInputBorder()),
                ),
              const SizedBox(height: 10),
              TextField(
                controller: descriptionController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Description (optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (numberController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Room number is required'), backgroundColor: AppColors.error),
                      );
                      return;
                    }
                    Navigator.pop(sheetContext);
                    final response = existing == null
                        ? await _apiService.createLodgeRoom(
                            roomNumber: numberController.text.trim(),
                            roomType: typeController.text.trim().isEmpty ? null : typeController.text.trim(),
                            rate: double.tryParse(rateController.text),
                            purpose: purpose,
                            occupant: occupantController.text.trim().isEmpty ? null : occupantController.text.trim(),
                            description: descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(),
                          )
                        : await _apiService.editLodgeRoom(
                            roomId: existing.roomId,
                            roomNumber: numberController.text.trim(),
                            roomType: typeController.text.trim().isEmpty ? null : typeController.text.trim(),
                            rate: double.tryParse(rateController.text),
                            purpose: purpose,
                            occupant: occupantController.text.trim().isEmpty ? null : occupantController.text.trim(),
                            description: descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(),
                          );
                    if (!mounted) return;
                    if (response.isSuccess) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Room saved.'), backgroundColor: AppColors.success),
                      );
                      _load();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(response.message), backgroundColor: AppColors.error),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'occupied':
        return AppColors.error;
      case 'cleaning':
        return AppColors.info;
      case 'maintenance':
        return Colors.grey;
      default:
        return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final permissions = context.watch<PermissionProvider>();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: LodgeTheme.appBar(isDark: isDark, eyebrow: 'Availability', title: 'Rooms'),
      floatingActionButton: permissions.hasPermission(PermissionIds.lodgeRoomsAdd)
          ? LodgeFab(onPressed: () => _showRoomFormSheet(), label: 'Room')
          : null,
      body: _buildBody(isDark, permissions),
    );
  }

  Widget _buildBody(bool isDark, PermissionProvider permissions) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMessage!),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      );
    }

    final canChangeStatus = permissions.hasPermission(PermissionIds.lodgeRoomsStatus);
    final canEdit = permissions.hasPermission(PermissionIds.lodgeRoomsEdit);
    final canSeeMaintenance = permissions.hasPermission(PermissionIds.lodgeMaintenance);
    final canDelete = permissions.hasPermission(PermissionIds.lodgeRoomsDelete);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _rooms.length,
        itemBuilder: (_, i) {
          final room = _rooms[i];
          final color = _statusColor(room.status);
          final hasMenu = (room.forSale && canChangeStatus) || canEdit || canSeeMaintenance || canDelete;

          return Card(
            color: isDark ? AppColors.darkCard : Colors.white,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
            ),
            elevation: 0,
            child: ListTile(
              leading: LodgeArchIcon(
                icon: Icons.hotel_outlined,
                width: 38,
                height: 44,
                background: color.withOpacity(isDark ? 0.3 : 0.15),
                foreground: color,
              ),
              title: Text('${room.roomNumber} ${room.roomType ?? ''}', style: LodgeTheme.body(size: 14.5, weight: FontWeight.w700)),
              subtitle: Text([
                room.forSale
                    ? '${Formatters.formatCurrency(room.rate)}/night'
                    : (room.occupant ?? 'Staff/Office'),
                if (room.lastMaintenance != null)
                  'Last maintenance: ${Formatters.formatDate(room.lastMaintenance)}',
                if (room.description != null && room.description!.isNotEmpty) room.description!,
              ].join(' · ')),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  room.status == 'occupied'
                      ? const LodgeStatusBadge(label: 'Occupied')
                      : Text(room.statusLabel ?? room.status,
                          style: LodgeTheme.body(size: 12.5, color: color, weight: FontWeight.w600)),
                  if (hasMenu)
                    PopupMenuButton<String>(
                      onSelected: (action) {
                        switch (action) {
                          case 'status':
                            _changeStatus(room);
                            break;
                          case 'edit':
                            _showRoomFormSheet(existing: room);
                            break;
                          case 'maintenance':
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => LodgeMaintenanceScreen(room: room)),
                            ).then((_) => _load());
                            break;
                          case 'delete':
                            _deleteRoom(room);
                            break;
                        }
                      },
                      itemBuilder: (_) => [
                        if (room.forSale && canChangeStatus)
                          const PopupMenuItem(value: 'status', child: Text('Change status')),
                        if (canEdit) const PopupMenuItem(value: 'edit', child: Text('Edit room')),
                        if (canSeeMaintenance) const PopupMenuItem(value: 'maintenance', child: Text('Maintenance')),
                        if (canDelete)
                          const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppColors.error))),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
