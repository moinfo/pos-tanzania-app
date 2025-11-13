import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/permission_provider.dart';

/// Widget that shows/hides its child based on permission
class PermissionWrapper extends StatelessWidget {
  final String? permissionId;
  final List<String>? anyPermissions;
  final List<String>? allPermissions;
  final Widget child;
  final Widget? fallback;
  final bool showFallbackForNoPermission;

  const PermissionWrapper({
    Key? key,
    this.permissionId,
    this.anyPermissions,
    this.allPermissions,
    required this.child,
    this.fallback,
    this.showFallbackForNoPermission = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final permissionProvider = Provider.of<PermissionProvider>(context);

    bool hasAccess = false;

    if (permissionId != null) {
      hasAccess = permissionProvider.hasPermission(permissionId!);
    } else if (anyPermissions != null && anyPermissions!.isNotEmpty) {
      hasAccess = permissionProvider.hasAnyPermission(anyPermissions!);
    } else if (allPermissions != null && allPermissions!.isNotEmpty) {
      hasAccess = permissionProvider.hasAllPermissions(allPermissions!);
    } else {
      // No permission specified, show by default
      hasAccess = true;
    }

    if (hasAccess) {
      return child;
    } else {
      return showFallbackForNoPermission
          ? (fallback ?? const SizedBox.shrink())
          : const SizedBox.shrink();
    }
  }
}

/// Widget that conditionally enables/disables based on permission
class PermissionEnabler extends StatelessWidget {
  final String? permissionId;
  final List<String>? anyPermissions;
  final List<String>? allPermissions;
  final Widget Function(bool enabled) builder;

  const PermissionEnabler({
    Key? key,
    this.permissionId,
    this.anyPermissions,
    this.allPermissions,
    required this.builder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final permissionProvider = Provider.of<PermissionProvider>(context);

    bool hasAccess = false;

    if (permissionId != null) {
      hasAccess = permissionProvider.hasPermission(permissionId!);
    } else if (anyPermissions != null && anyPermissions!.isNotEmpty) {
      hasAccess = permissionProvider.hasAnyPermission(anyPermissions!);
    } else if (allPermissions != null && allPermissions!.isNotEmpty) {
      hasAccess = permissionProvider.hasAllPermissions(allPermissions!);
    } else {
      hasAccess = true;
    }

    return builder(hasAccess);
  }
}

/// Mixin to provide easy permission checking in widgets
mixin PermissionCheckMixin {
  bool hasPermission(BuildContext context, String permissionId) {
    final permissionProvider = Provider.of<PermissionProvider>(context, listen: false);
    return permissionProvider.hasPermission(permissionId);
  }

  bool hasModulePermission(BuildContext context, String moduleId) {
    final permissionProvider = Provider.of<PermissionProvider>(context, listen: false);
    return permissionProvider.hasModulePermission(moduleId);
  }

  bool hasAnyPermission(BuildContext context, List<String> permissionIds) {
    final permissionProvider = Provider.of<PermissionProvider>(context, listen: false);
    return permissionProvider.hasAnyPermission(permissionIds);
  }

  bool hasAllPermissions(BuildContext context, List<String> permissionIds) {
    final permissionProvider = Provider.of<PermissionProvider>(context, listen: false);
    return permissionProvider.hasAllPermissions(permissionIds);
  }
}

/// Button wrapper that automatically handles permission-based enabling/disabling
class PermissionButton extends StatelessWidget {
  final String? permissionId;
  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;
  final bool showDisabled;

  const PermissionButton({
    Key? key,
    this.permissionId,
    required this.onPressed,
    required this.child,
    this.style,
    this.showDisabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (permissionId == null) {
      return ElevatedButton(
        onPressed: onPressed,
        style: style,
        child: child,
      );
    }

    return PermissionEnabler(
      permissionId: permissionId,
      builder: (hasPermission) {
        if (!hasPermission && !showDisabled) {
          return const SizedBox.shrink();
        }

        return ElevatedButton(
          onPressed: hasPermission ? onPressed : null,
          style: style,
          child: child,
        );
      },
    );
  }
}

/// Icon button wrapper with permission checking
class PermissionIconButton extends StatelessWidget {
  final String? permissionId;
  final VoidCallback? onPressed;
  final Icon icon;
  final String? tooltip;
  final bool showDisabled;
  final Color? color;

  const PermissionIconButton({
    Key? key,
    this.permissionId,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.showDisabled = true,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (permissionId == null) {
      return IconButton(
        onPressed: onPressed,
        icon: icon,
        tooltip: tooltip,
        color: color,
      );
    }

    return PermissionEnabler(
      permissionId: permissionId,
      builder: (hasPermission) {
        if (!hasPermission && !showDisabled) {
          return const SizedBox.shrink();
        }

        return IconButton(
          onPressed: hasPermission ? onPressed : null,
          icon: icon,
          tooltip: tooltip,
          color: hasPermission ? color : Colors.grey,
        );
      },
    );
  }
}

/// FloatingActionButton wrapper with permission checking
class PermissionFAB extends StatelessWidget {
  final String? permissionId;
  final VoidCallback? onPressed;
  final Widget child;
  final String? tooltip;
  final bool showDisabled;

  const PermissionFAB({
    Key? key,
    this.permissionId,
    required this.onPressed,
    required this.child,
    this.tooltip,
    this.backgroundColor,
    this.showDisabled = false,
  }) : super(key: key);

  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    if (permissionId == null) {
      return FloatingActionButton(
        onPressed: onPressed,
        tooltip: tooltip,
        backgroundColor: backgroundColor,
        child: child,
      );
    }

    return PermissionWrapper(
      permissionId: permissionId,
      showFallbackForNoPermission: showDisabled,
      fallback: FloatingActionButton(
        onPressed: null,
        tooltip: tooltip,
        backgroundColor: Colors.grey,
        child: child,
      ),
      child: FloatingActionButton(
        onPressed: onPressed,
        backgroundColor: backgroundColor,
        tooltip: tooltip,
        child: child,
      ),
    );
  }
}
