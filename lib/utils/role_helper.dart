import '../config/constants.dart';

class RoleHelper {
  static bool canAccess(Role userRole, Role requiredRole) {
    return userRole == requiredRole || userRole == Role.admin;
  }

  static String getRoleLabel(Role role) {
    return AppConstants.roleNames[role] ?? 'Không xác định';
  }
}
