// The production API returns i18n KEYS, not prose.
//
// Production_lib::create_batch/close_batch/void_batch return
// array('success' => FALSE, 'message' => 'production_sand_mismatch'), and the
// controller passes that straight into send_error() without running it through
// CodeIgniter's lang(). The translations exist server-side
// (application/language/{en-US,en-GB,sw}/production_lang.php) but are never
// applied on the API path, so a raw key would otherwise reach the user.
//
// Mirrored from en-US/production_lang.php. If a key is missing here the raw
// key is shown rather than a wrong guess -- visibly odd, but debuggable.

const Map<String, String> _productionMessages = {
  'production_no_settings': 'Production settings are not configured yet',
  'production_item_required': 'Product is required',
  'production_no_recipe': 'No active recipe for this product',
  'production_invalid_bags': 'Bags used must be greater than zero',
  'production_sand_mismatch': 'Sand used must equal cement used (1:1 ratio)',
  'production_recipe_empty': 'The recipe has no raw materials',
  'production_raw_item_deleted': 'A raw material of this recipe has been deleted',
  'production_short_stock': 'Not enough raw material in stock',
  'production_batch_save_failed': 'Error saving batch',
  'production_batch_not_draft': 'Only draft batches can be closed',
  'production_invalid_output': 'Actual output must be greater than zero',
  'production_close_failed': 'Error closing batch',
  'production_batch_not_found': 'Batch not found',
  'production_void_failed': 'Error voiding batch',
  'production_no_void_grant': 'You do not have permission to void batches',
  'production_no_grant': 'You do not have permission for this action',
  'production_batch_created': 'Batch created, stock updated',
  'production_batch_closed': 'Batch closed, stock moved to curing',
  'production_batch_voided': 'Batch voided and stock reversed',
  'production_efficiency_warning':
      'Efficiency below tolerance - check with the operator',
};

/// Turn a production API message into something readable.
///
/// Passes anything that is not a known key straight through: the controller
/// also emits plain English for its own errors ("Batch not found", "Method not
/// allowed"), and those must not be mangled.
String productionErrorMessage(String raw) => _productionMessages[raw] ?? raw;
