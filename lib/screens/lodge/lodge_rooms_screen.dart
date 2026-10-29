import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/lodge.dart';
import '../../models/permission_model.dart';
import '../../providers/permission_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';

/// `GET lodge/rooms` -- README 3.10. Room add/edit/maintenance forms are a
/// later phase; this screen covers the list and the vacant/cleaning/
/// maintenance status change (`lodge_rooms_status`), which is the thing
/// housekeeping actually needs day to day.
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
    final headerColor = isDark ? AppColors.darkSurface : AppColors.brandPrimary;
    final canChangeStatus = permissions.hasPermission(PermissionIds.lodgeRoomsStatus);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: headerColor,
        foregroundColor: Colors.white,
        title: const Text('Rooms'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_errorMessage!),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _load, child: const Text('Try again')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _rooms.length,
                    itemBuilder: (_, i) {
                      final room = _rooms[i];
                      final color = _statusColor(room.status);
                      return Card(
                        color: isDark ? AppColors.darkCard : Colors.white,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: color.withOpacity(0.15),
                            child: Icon(Icons.hotel, color: color, size: 20),
                          ),
                          title: Text('${room.roomNumber} ${room.roomType ?? ''}'),
                          subtitle: Text([
                            room.forSale
                                ? '${Formatters.formatCurrency(room.rate)}/night'
                                : (room.occupant ?? 'Staff/Office'),
                            if (room.lastMaintenance != null)
                              'Last maintenance: ${Formatters.formatDate(room.lastMaintenance)}',
                          ].join(' · ')),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(room.statusLabel ?? room.status,
                                  style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12.5)),
                              if (room.forSale && canChangeStatus)
                                IconButton(
                                  icon: const Icon(Icons.more_vert),
                                  onPressed: () => _changeStatus(room),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
