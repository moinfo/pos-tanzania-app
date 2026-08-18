import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_tanzania_mobile/models/item_approval.dart';

// Payload shapes mirror application/controllers/api/Item_approvals.php.
// PHP sends decimals as strings ("55000.00") and ints as ints, so the
// parsing has to survive both.
void main() {
  group('ItemApproval', () {
    test('parses an edit request and separates changed from unchanged', () {
      final data = json.decode('''
      {
        "request_id": 7, "change_type": "edit", "item_id": 913,
        "item_name": "BLOCK 6 PLAIN", "status": "pending",
        "requested_by": 22, "requester_name": "Asha Mwinyi",
        "created_at": "2026-08-18 09:12:03",
        "field_diffs": [
          {"field":"name","before":"BLOCK 6 PLAIN","after":"BLOCK 6 PLAIN","changed":false},
          {"field":"unit_price","before":"55000.00","after":58000,"changed":true},
          {"field":"supplier_id","before":"(none)","after":"Napenekemu Ltd","changed":true}
        ],
        "quantity_diffs": [
          {"field":"1","before":100,"after":120,"changed":true},
          {"field":"2","before":5,"after":5,"changed":false}
        ]
      }''') as Map<String, dynamic>;

      final r = ItemApproval.fromJson(data);

      expect(r.requestId, 7);
      expect(r.isEdit, isTrue);
      expect(r.displayName, 'BLOCK 6 PLAIN');
      expect(r.changeTypeLabel, 'Item edit');
      expect(r.changedFields.length, 2);
      expect(r.unchangedFields.length, 1);
      expect(r.changedQuantities.length, 1);
      // string decimal vs int must both survive as labels
      expect(r.changedFields.first.beforeLabel, '55000.00');
      expect(r.changedFields.first.afterLabel, '58000');
    });

    test('an add request has no item row, so the name comes from the diffs', () {
      final data = json.decode('''
      {
        "request_id": 9, "change_type": "add", "item_id": null,
        "item_name": null, "status": "pending",
        "requested_by": 22, "requester_name": "Asha Mwinyi",
        "created_at": "2026-08-18 10:02:00",
        "field_diffs": [
          {"field":"name","before":null,"after":"BLOCK 5 INCH","changed":true},
          {"field":"unit_price","before":null,"after":"48000.00","changed":true}
        ],
        "quantity_diffs": []
      }''') as Map<String, dynamic>;

      final r = ItemApproval.fromJson(data);

      expect(r.isAdd, isTrue);
      expect(r.itemId, isNull);
      expect(r.displayName, 'BLOCK 5 INCH');
      expect(r.changedFields.first.beforeLabel, '—');
    });

    test('an add row in the LIST response cannot be named', () {
      // The list endpoint sends no diffs, and item_name is a LEFT JOIN on a
      // row that does not exist yet -- so this is the honest fallback.
      final r = ItemApproval.fromJson(json.decode('''
      {
        "request_id": 9, "change_type": "add", "item_id": null,
        "item_name": null, "status": "pending", "requested_by": 22,
        "requester_name": "Asha Mwinyi", "created_at": "2026-08-18 10:02:00"
      }''') as Map<String, dynamic>);

      expect(r.displayName, 'New item');
      expect(r.fieldDiffs, isEmpty);
    });

    test('parses an inventory request', () {
      final r = ItemApproval.fromJson(json.decode('''
      {
        "request_id": 11, "change_type": "inventory", "item_id": 913,
        "item_name": "CEMENT 3812", "status": "pending", "requested_by": 22,
        "requester_name": "Juma Said", "created_at": "2026-08-18 11:00:00",
        "diff": {
          "location": "PRODUCTION", "trans_comment": "spillage",
          "delta": -3.5, "before_qty": 110, "after_qty": 106.5
        }
      }''') as Map<String, dynamic>);

      expect(r.isInventory, isTrue);
      expect(r.inventoryDiff, isNotNull);
      expect(r.inventoryDiff!.location, 'PRODUCTION');
      expect(r.inventoryDiff!.delta, -3.5);
      expect(r.inventoryDiff!.afterQty, 106.5);
      expect(r.fieldDiffs, isEmpty);
    });

    test('list response parses and tolerates a missing total', () {
      final list = ItemApprovalListResponse.fromJson(json.decode('''
      {"requests":[
        {"request_id":1,"change_type":"edit","item_id":5,"item_name":"X",
         "status":"pending","requested_by":2,"requester_name":"A","created_at":"2026-08-18 09:00:00"}
      ],"total":1}''') as Map<String, dynamic>);

      expect(list.total, 1);
      expect(list.requests.single.displayName, 'X');

      final empty = ItemApprovalListResponse.fromJson(
          json.decode('{"requests":[]}') as Map<String, dynamic>);
      expect(empty.requests, isEmpty);
      expect(empty.total, 0);
    });
  });
}
