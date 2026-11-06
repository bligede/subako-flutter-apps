import '../../shared/models/enums.dart';
import '../../shared/models/models.dart';

/// Permission granular yang dipakai UI dan divalidasi ulang di server.
class Permissions {
  const Permissions._();

  static const String viewDashboard = 'dashboard.view';
  static const String viewMonitoring = 'monitoring.view';
  static const String viewLedger = 'ledger.view';
  static const String acknowledgeAlert = 'alert.acknowledge';
  static const String sendGateCommand = 'gate.command';
  static const String viewRules = 'rule.view';
  static const String manageRules = 'rule.manage';
  static const String approveRules = 'rule.approve';
  static const String manageDevices = 'device.manage';
  static const String manageMembers = 'member.manage';
  static const String viewAudit = 'audit.view';

  static const Map<UserRole, Set<String>> _matrix = <UserRole, Set<String>>{
    UserRole.farmerViewer: <String>{
      viewDashboard,
      viewMonitoring,
      viewLedger,
      viewRules,
    },
    UserRole.operator: <String>{
      viewDashboard,
      viewMonitoring,
      viewLedger,
      viewRules,
      acknowledgeAlert,
      sendGateCommand,
    },
    UserRole.pekaseh: <String>{
      viewDashboard,
      viewMonitoring,
      viewLedger,
      viewRules,
      acknowledgeAlert,
      manageRules,
      approveRules,
      viewAudit,
    },
    UserRole.mikikoAdmin: <String>{
      viewDashboard,
      viewMonitoring,
      viewLedger,
      viewRules,
      viewAudit,
      manageDevices,
      acknowledgeAlert,
    },
    UserRole.platformAdmin: <String>{
      viewDashboard,
      viewMonitoring,
      viewLedger,
      viewRules,
      viewAudit,
      manageDevices,
      manageMembers,
    },
  };

  static Set<String> of(UserRole role) => _matrix[role] ?? const <String>{};

  static bool can(UserRole role, String permission) =>
      of(role).contains(permission);

  static bool forUser(UserProfile user, String permission) =>
      (user.grantedPermissions ?? of(user.role)).contains(permission);

  /// Admin Mikiko tidak otomatis berwenang menentukan alokasi air.
  static bool canDecideAllocation(UserRole role) =>
      role == UserRole.pekaseh || role == UserRole.platformAdmin
      ? role == UserRole.pekaseh
      : false;

  /// Hanya peran ini yang boleh menyetujui/menerbitkan aturan.
  static bool canApproveRule(UserRole role) =>
      can(role, approveRules) && role == UserRole.pekaseh;
}
