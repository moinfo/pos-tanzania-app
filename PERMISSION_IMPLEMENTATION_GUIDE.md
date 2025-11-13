# Permission System Implementation Guide

## Overview

The permission system has been implemented in the mobile app to control user access to features based on their assigned permissions from the web application.

## Architecture

### 1. Models (`lib/models/permission_model.dart`)
- `Permission`: Represents a single permission
- `UserPermissionsResponse`: API response wrapper
- `PermissionIds`: Constants for all permission IDs

### 2. Provider (`lib/providers/permission_provider.dart`)
- Manages user permissions
- Provides methods to check permissions
- Handles local storage and API sync

### 3. Widgets (`lib/widgets/permission_wrapper.dart`)
- `PermissionWrapper`: Show/hide widgets based on permission
- `PermissionEnabler`: Enable/disable widgets based on permission
- `PermissionButton`: Button with automatic permission checking
- `PermissionIconButton`: Icon button with permission checking
- `PermissionFAB`: Floating action button with permission checking
- `PermissionCheckMixin`: Mixin for easy permission checking

### 4. Backend API (`application/controllers/api/Auth.php`)
- GET `/api/auth/permissions` - Returns user permissions

## Usage Examples

### 1. Hide/Show Widgets

```dart
import '../widgets/permission_wrapper.dart';
import '../models/permission_model.dart';

// Show only if user has permission
PermissionWrapper(
  permissionId: PermissionIds.itemsAdd,
  child: FloatingActionButton(
    onPressed: () => _addItem(),
    child: const Icon(Icons.add),
  ),
)

// Show if user has ANY of the permissions
PermissionWrapper(
  anyPermissions: [PermissionIds.itemsAdd, PermissionIds.itemsEdit],
  child: ElevatedButton(
    onPressed: () => _saveItem(),
    child: const Text('Save'),
  ),
)

// Show if user has ALL permissions
PermissionWrapper(
  allPermissions: [PermissionIds.itemsAdd, PermissionIds.itemsStock],
  child: ElevatedButton(
    onPressed: () => _addStock(),
    child: const Text('Add Stock'),
  ),
)
```

### 2. Enable/Disable Widgets

```dart
// Enable button only if user has permission
PermissionEnabler(
  permissionId: PermissionIds.itemsDelete,
  builder: (hasPermission) => ElevatedButton(
    onPressed: hasPermission ? () => _deleteItem() : null,
    child: const Text('Delete'),
  ),
)
```

### 3. Using Permission Buttons

```dart
// Floating Action Button with permission
PermissionFAB(
  permissionId: PermissionIds.itemsAdd,
  onPressed: () => _addItem(),
  tooltip: 'Add Item',
  child: const Icon(Icons.add),
)

// Icon Button with permission
PermissionIconButton(
  permissionId: PermissionIds.itemsDelete,
  onPressed: () => _deleteItem(),
  icon: const Icon(Icons.delete),
  tooltip: 'Delete Item',
  color: Colors.red,
)

// Regular Button with permission
PermissionButton(
  permissionId: PermissionIds.itemsAdd,
  onPressed: () => _saveItem(),
  child: const Text('Save'),
)
```

### 4. Using Permission Mixin

```dart
import '../widgets/permission_wrapper.dart';

class MyWidget extends StatefulWidget with PermissionCheckMixin {
  // ...

  void _handleAction() {
    if (hasPermission(context, PermissionIds.itemsDelete)) {
      // User has permission
      _deleteItem();
    } else {
      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No permission to delete items')),
      );
    }
  }

  void _checkModuleAccess() {
    if (hasModulePermission(context, PermissionIds.items)) {
      // User has items module access
      _navigateToItems();
    }
  }
}
```

### 5. Direct Permission Checking

```dart
import 'package:provider/provider.dart';
import '../providers/permission_provider.dart';
import '../models/permission_model.dart';

// In your widget build method or methods
Widget build(BuildContext context) {
  final permissionProvider = Provider.of<PermissionProvider>(context);

  // Check single permission
  final canAddItems = permissionProvider.hasPermission(PermissionIds.itemsAdd);

  // Check module permission
  final canAccessItems = permissionProvider.hasModulePermission(PermissionIds.items);

  // Check multiple permissions (ANY)
  final canModify = permissionProvider.hasAnyPermission([
    PermissionIds.itemsAdd,
    PermissionIds.itemsEdit,
  ]);

  // Check multiple permissions (ALL)
  final canFullAccess = permissionProvider.hasAllPermissions([
    PermissionIds.items,
    PermissionIds.itemsStock,
  ]);

  return Scaffold(
    // ... your widget tree
  );
}
```

## Implementation for Each Screen

### Items Screen

```dart
// Add button (FAB)
floatingActionButton: PermissionFAB(
  permissionId: PermissionIds.itemsAdd,
  onPressed: () => _showItemForm(),
  tooltip: 'Add Item',
  child: const Icon(Icons.add),
),

// Delete button in list item
trailing: PermissionIconButton(
  permissionId: PermissionIds.itemsDelete,
  onPressed: () => _deleteItem(item),
  icon: const Icon(Icons.delete),
  color: AppColors.error,
  showDisabled: false, // Hide if no permission
),
```

### Sales Screen

```dart
// Checkout button
PermissionButton(
  permissionId: PermissionIds.salesAdd,
  onPressed: () => _checkout(),
  child: const Text('Complete Sale'),
),

// Process return button
PermissionButton(
  permissionId: PermissionIds.salesChangeModeReturn,
  onPressed: () => _processReturn(),
  child: const Text('Process Return'),
),

// Suspend sale button
PermissionButton(
  permissionId: PermissionIds.salesSuspended,
  onPressed: () => _suspendSale(),
  child: const Text('Suspend Sale'),
),
```

### Customers Screen

```dart
// Add customer FAB
floatingActionButton: PermissionFAB(
  permissionId: PermissionIds.customersAdd,
  onPressed: () => _addCustomer(),
  tooltip: 'Add Customer',
  child: const Icon(Icons.person_add),
),

// Edit button
PermissionIconButton(
  permissionId: PermissionIds.customersEdit,
  onPressed: () => _editCustomer(customer),
  icon: const Icon(Icons.edit),
),

// Delete button
PermissionIconButton(
  permissionId: PermissionIds.customersDelete,
  onPressed: () => _deleteCustomer(customer),
  icon: const Icon(Icons.delete),
  color: AppColors.error,
),
```

### Receivings Screen

```dart
// Add receiving button
PermissionButton(
  permissionId: PermissionIds.receivingsAdd,
  onPressed: () => _addReceiving(),
  child: const Text('New Receiving'),
),
```

### Cash Submit Screen

```dart
// Submit button (requires multiple permissions)
PermissionButton(
  permissionId: PermissionIds.cashSubmitAdd,
  onPressed: () => _submitCash(),
  child: const Text('Submit Cash'),
),

// View all button (admin only)
PermissionWrapper(
  permissionId: PermissionIds.cashSubmitAdmin,
  child: ElevatedButton(
    onPressed: () => _viewAllSubmissions(),
    child: const Text('View All Submissions'),
  ),
),

// Supervisor approval section
PermissionWrapper(
  permissionId: PermissionIds.cashSubmitSupervisor,
  child: Column(
    children: [
      // Supervisor-only UI
    ],
  ),
),
```

### Banking Screen

```dart
// Add withdrawal button
PermissionButton(
  permissionId: PermissionIds.withdrawalAdd,
  onPressed: () => _addWithdrawal(),
  child: const Text('Add Withdrawal'),
),

// Delete button
PermissionIconButton(
  permissionId: PermissionIds.withdrawalDelete,
  onPressed: () => _deleteEntry(entry),
  icon: const Icon(Icons.delete),
  color: AppColors.error,
),
```

### Expenses Screen

```dart
// Add expense FAB
floatingActionButton: PermissionFAB(
  permissionId: PermissionIds.expensesAdd,
  onPressed: () => _addExpense(),
  tooltip: 'Add Expense',
  child: const Icon(Icons.add),
),

// Delete button
PermissionIconButton(
  permissionId: PermissionIds.expensesDelete,
  onPressed: () => _deleteExpense(expense),
  icon: const Icon(Icons.delete),
  color: AppColors.error,
),
```

### Reports Screen

```dart
// Show reports based on permissions
Widget _buildReportsList() {
  final permissionProvider = Provider.of<PermissionProvider>(context);

  return ListView(
    children: [
      if (permissionProvider.hasPermission(PermissionIds.reportsSales))
        ListTile(
          title: const Text('Sales Reports'),
          onTap: () => _showSalesReports(),
        ),

      if (permissionProvider.hasPermission(PermissionIds.reportsInventory))
        ListTile(
          title: const Text('Inventory Reports'),
          onTap: () => _showInventoryReports(),
        ),

      if (permissionProvider.hasPermission(PermissionIds.reportsCustomers))
        ListTile(
          title: const Text('Customer Reports'),
          onTap: () => _showCustomerReports(),
        ),

      // ... other reports
    ],
  );
}
```

## Permission IDs Reference

### Module Permissions
- `items` - Items module access
- `sales` - Sales module access
- `receivings` - Receivings module access
- `customers` - Customers module access
- `suppliers` - Suppliers module access
- `reports` - Reports module access

### Action Permissions
- `items_add` - Add items
- `items_delete` - Delete items
- `items_categories` - Manage categories
- `sales_add` - Create sales
- `sales_change_mode_return` - Process returns
- `sales_suspended` - Suspend sales
- `receivings_add` - Create receivings
- `customers_add` - Add customers
- `customers_delete` - Delete customers
- `customers_edit` - Edit customers
- `cash_submit_add` - Submit cash
- `cash_submit_view` - View cash submissions
- `cash_submit_admin` - Admin access to cash submissions
- `withdrawal_add` - Add withdrawals
- `withdrawal_delete` - Delete withdrawals
- `expenses_add` - Add expenses
- `expenses_delete` - Delete expenses

See `lib/models/permission_model.dart` for complete list of permission IDs.

## Testing

### Test with Different User Roles

1. **Admin User** (all permissions):
   - All buttons should be visible and enabled

2. **Sales User** (limited permissions):
   - Can access Sales, Customers
   - Cannot access Items, Receivings, Reports

3. **Cashier User** (minimal permissions):
   - Can only create sales
   - Cannot delete, edit, or access other modules

### Testing Steps

1. Create test users in the web application with different permission sets
2. Login to mobile app with each user
3. Verify buttons appear/disappear based on permissions
4. Try to perform actions without permission (should be prevented)
5. Check that the UI gracefully handles missing permissions

## Debugging

```dart
// Print all user permissions (useful for debugging)
final permissionProvider = Provider.of<PermissionProvider>(context, listen: false);
permissionProvider.debugPrintPermissions();

// Check if permissions are loaded
print('Permissions loaded: ${permissionProvider.permissions.length}');

// Check specific permission
print('Has items_add: ${permissionProvider.hasPermission(PermissionIds.itemsAdd)}');
```

## Best Practices

1. **Always check permissions** before showing action buttons
2. **Use `showDisabled: false`** to hide buttons instead of showing them disabled
3. **Provide feedback** when user tries to perform action without permission
4. **Test with different user roles** to ensure proper access control
5. **Keep permissions in sync** with backend permissions
6. **Use module permissions** for screen-level access control
7. **Use action permissions** for button-level access control
8. **Cache permissions locally** for offline access
9. **Refresh permissions** after login or on app startup
10. **Clear permissions** on logout for security

## Troubleshooting

### Permissions not loading
- Check API endpoint is accessible
- Verify JWT token is valid
- Check network connection
- Look for errors in permission_provider

### Buttons not showing/hiding
- Verify permission ID is correct
- Check permission is granted in database
- Ensure PermissionProvider is properly registered in main.dart
- Check widget is wrapped with correct permission widget

### API returns 403 Forbidden
- User doesn't have required permission
- Permission not granted in grants table
- Check module_id and permission_id match

## Next Steps

1. Apply permissions to all screens
2. Test with different user roles
3. Add permission checks to API calls (backend)
4. Implement permission-based navigation
5. Add permission documentation for users
