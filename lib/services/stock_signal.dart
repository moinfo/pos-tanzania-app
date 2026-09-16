import 'package:flutter/foundation.dart';

/// Announced whenever something this app did changed stock on the server.
///
/// The screens that show quantities load them once -- the sale screen when it
/// mounts or the store is switched, the items screen when it opens -- and then
/// keep what they loaded. That is right for a catalogue of names and prices,
/// but the stock numbers travel with it, so booking a receiving on another
/// screen left the sale screen showing the quantities from before the delivery
/// while the database was already correct.
///
/// A signal rather than a shared stock cache on purpose: the screens disagree
/// about what they need (the sale screen wants one location, lean; the items
/// screen wants the full shape), so the cheap, honest fix is to tell them their
/// copy is stale and let each refetch the way it already knows how.
///
/// Listeners refetch from the server, so only bump this after a change the
/// server has ACCEPTED. A queued receiving has not changed any stock yet; it
/// bumps when the sync uploads it.
class StockSignal {
  StockSignal._();

  /// Bumped on every accepted stock change. Screens listen and reload.
  static final ValueNotifier<int> changed = ValueNotifier<int>(0);

  static void bump() {
    changed.value++;
    debugPrint('StockSignal: stock changed (${changed.value})');
  }
}
