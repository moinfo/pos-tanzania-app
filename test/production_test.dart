import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_tanzania_mobile/models/production.dart';
import 'package:pos_tanzania_mobile/models/production_report.dart';
import 'package:pos_tanzania_mobile/models/cash_movement.dart';
import 'package:pos_tanzania_mobile/utils/production_messages.dart';

// MySQL DECIMAL columns come back from PHP as strings ("55000.00", "1.000"),
// and tinyint(1) as "1"/"0" -- these tests pin that down, because a naive
// parse would silently produce 0 for every cost on the screen.
void main() {
  group('ProductionBatch', () {
    test('parses decimal strings and a null actual_output on a draft', () {
      final b = ProductionBatch.fromJson(json.decode('''
      {
        "batch_id": 12, "batch_no": "B-0012", "production_date": "2026-08-18",
        "item_id": 913, "item_name": "BLOCK 6 PLAIN",
        "recipe_id": 3, "recipe_name": "6 PLAIN standard",
        "lot_id": 4, "lot_no": "L-004",
        "bags_used": "30.00", "expected_output": "1260.000",
        "actual_output": null, "rejects": "0.000", "efficiency_pct": null,
        "direct_cost_total": "585000.00", "actual_cost_total": "0.00",
        "cost_variance": "-585000.00", "cost_per_unit": null,
        "status": "draft"
      }''') as Map<String, dynamic>);

      expect(b.bagsUsed, 30.0);
      expect(b.expectedOutput, 1260.0);
      expect(b.actualOutput, isNull);
      expect(b.directCostTotal, 585000.0);
      expect(b.isDraft, isTrue);
      expect(b.canClose, isTrue);
      // No expense linked yet -- the reconciliation report flags this.
      expect(b.hasNoLinkedExpense, isTrue);
    });

    test('a closed batch is not closable again', () {
      final b = ProductionBatch.fromJson(json.decode('''
      {
        "batch_id": 13, "batch_no": "B-0013", "production_date": "2026-08-17",
        "item_id": 913, "bags_used": "30.00", "expected_output": "1260.000",
        "actual_output": "1240.000", "rejects": "5.000",
        "efficiency_pct": "98.41", "direct_cost_total": "585000.00",
        "actual_cost_total": "590000.00", "cost_variance": "5000.00",
        "cost_per_unit": "471.7742", "status": "ready"
      }''') as Map<String, dynamic>);

      expect(b.canClose, isFalse);
      expect(b.isReady, isTrue);
      expect(b.actualOutput, 1240.0);
      expect(b.costPerUnit, closeTo(471.7742, 0.0001));
      expect(b.hasNoLinkedExpense, isFalse);
    });
  });

  group('ProductionLot', () {
    test('computes remaining bags', () {
      final lot = ProductionLot.fromJson(json.decode('''
      {
        "lot_id": 4, "lot_no": "L-004", "opened_on": "2026-08-01",
        "material_cost": "300000.00", "transport_cost": "50000.00",
        "utility_cost": "10000.00", "total_cost": "360000.00",
        "expected_bags": "30.00", "bags_consumed": "18.00",
        "cost_per_bag": "12000.0000", "status": "active", "notes": ""
      }''') as Map<String, dynamic>);

      expect(lot.isActive, isTrue);
      expect(lot.bagsRemaining, 12.0);
      expect(lot.costPerBag, 12000.0);
      expect(lot.notes, isNull); // empty string normalises to null
    });
  });

  group('ProductionRecipe', () {
    test('reads tinyint is_active as a string and nested items', () {
      final r = ProductionRecipe.fromJson(json.decode('''
      {
        "recipe_id": 3, "item_id": 913, "name": "6 PLAIN standard",
        "standard_yield_per_bag": "42.000", "curing_days": null,
        "effective_from": "2026-08-01", "is_active": "1",
        "items": [{"item_id": 3812, "name": "CEMENT 3812", "qty_per_bag": "1.000000"}]
      }''') as Map<String, dynamic>);

      expect(r.isActive, isTrue);
      expect(r.standardYieldPerBag, 42.0);
      expect(r.curingDays, isNull); // NULL = fall back to settings
      expect(r.items.single.itemName, 'CEMENT 3812');
      expect(r.items.single.qtyPerBag, 1.0);
    });
  });

  group('ProductionSettings', () {
    test('reads flags and detects a no-curing configuration', () {
      final s = ProductionSettings.fromJson(json.decode('''
      {
        "setting_id": 1, "production_location_id": 2, "curing_location_id": null,
        "default_curing_days": "0", "raw_valuation": "AVG",
        "block_on_short_stock": "1", "reserve_for_sale": "0",
        "tolerance_pct": "5.00", "auto_release_cured": "1"
      }''') as Map<String, dynamic>);

      expect(s.blockOnShortStock, isTrue);
      expect(s.reserveForSale, isFalse);
      expect(s.tolerancePct, 5.0);
      expect(s.hasCuringStep, isFalse);
    });
  });

  group('ProductionReport', () {
    test('reads the field out of a single-entry column map', () {
      final report = ProductionReport.fromJson(json.decode('''
      {
        "columns": [
          {"production_date": "Production Date"},
          {"batch_no": "Batch No"},
          {"bags_used": "Bags Used", "sorter": "number_sorter"}
        ],
        "data": [
          {"production_date": "2026-08-18", "batch_no": "B-0012", "bags_used": "30.00"}
        ],
        "summary": {"total_batches": "4", "avg_cost_per_unit": "471.77"}
      }''') as Map<String, dynamic>);

      expect(report.columns.length, 3);
      expect(report.columns[0].field, 'production_date');
      expect(report.columns[0].label, 'Production Date');
      expect(report.columns[0].isNumeric, isFalse);
      // 'sorter' must not be mistaken for the field name.
      expect(report.columns[2].field, 'bags_used');
      expect(report.columns[2].isNumeric, isTrue);
      expect(report.rows.single['batch_no'], 'B-0012');
      expect(report.summary['total_batches'], '4');
    });

    test('survives an empty report', () {
      final report = ProductionReport.fromJson(
          json.decode('{"columns":[],"data":[],"summary":{}}') as Map<String, dynamic>);
      expect(report.isEmpty, isTrue);
      expect(report.columns, isEmpty);
    });
  });

  group('CashMovement', () {
    test('parses a list and totals it', () {
      final list = CashMovementListResponse.fromJson(json.decode('''
      {"movements":[
        {"id":1,"type":"deposit","amount":50000,"date":"2026-08-17",
         "comment":"from branch","supervisor_id":9,"created_at":"2026-08-17 10:00:00"},
        {"id":2,"type":"deposit","amount":25000.5,"date":"2026-08-18",
         "comment":"","supervisor_id":null,"created_at":"2026-08-18 09:00:00"}
      ],"total":2}''') as Map<String, dynamic>);

      expect(list.total, 2);
      expect(list.totalAmount, 75000.5);
      expect(list.movements.first.isDeposit, isTrue);
      expect(list.movements.last.comment, isNull);
      expect(list.movements.last.supervisorId, isNull);
    });
  });

  group('productionErrorMessage', () {
    test('translates known lang keys', () {
      expect(productionErrorMessage('production_sand_mismatch'),
          'Sand used must equal cement used (1:1 ratio)');
      expect(productionErrorMessage('production_no_recipe'),
          'No active recipe for this product');
    });

    test('passes through anything that is not a key', () {
      // The controller emits plain English of its own; it must survive intact.
      expect(productionErrorMessage('Batch not found'), 'Batch not found');
      expect(productionErrorMessage('Method not allowed'), 'Method not allowed');
    });
  });
}
