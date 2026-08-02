import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/stock_location.dart';
import '../providers/location_provider.dart';
import '../utils/constants.dart';

/// The active stock location, shown as an app bar title and doubling as the
/// store switcher.
///
/// Extracted so pushed screens use the SAME top bar as the main shell instead of
/// each inventing its own location chip in `actions` -- those chips competed
/// with the screen title for width and ended up truncated ("Debt Coll..." next
/// to "APOLINARY ...").
///
/// A seller granted a single store gets a plain label: there is nothing to
/// switch to, and a chevron would imply otherwise.
class StoreSwitcherTitle extends StatelessWidget {
  /// Optional screen name shown above the store, e.g. "Debt Collection".
  final String? subtitle;

  const StoreSwitcherTitle({super.key, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Consumer<LocationProvider>(
      builder: (context, locationProvider, child) {
        final selected = locationProvider.selectedLocation;
        final canSwitch = locationProvider.hasMultipleLocations;

        if (selected == null) {
          return Text(
            subtitle ?? AppConstants.appName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          );
        }

        final label = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (subtitle != null)
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    selected.locationName.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                if (canSwitch)
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 20, color: Colors.white70),
              ],
            ),
          ],
        );

        if (!canSwitch) return label;

        return PopupMenuButton<StockLocation>(
          offset: const Offset(0, 40),
          color: Colors.white,
          tooltip: 'Switch store',
          onSelected: (location) => locationProvider.selectLocation(location),
          itemBuilder: (context) => locationProvider.allowedLocations
              .map(
                (location) => PopupMenuItem<StockLocation>(
                  value: location,
                  child: Row(
                    children: [
                      Icon(
                        location.locationId == selected.locationId
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 20,
                        color: location.locationId == selected.locationId
                            ? AppColors.primary
                            : Colors.grey,
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          location.locationName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
          child: label,
        );
      },
    );
  }
}
