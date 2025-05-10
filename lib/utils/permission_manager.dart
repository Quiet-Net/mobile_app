import 'package:permission_handler/permission_handler.dart';

enum PermissionType {
  microphone,
  camera,
  storage,
  notification,
  location,
  contacts,
  photos,
}

class RequestPermissionManager {
  PermissionType? _permissionType;
  Function()? _onPermissionDenied;
  Function()? _onPermissionGranted;
  Function()? _onPermissionPermanentlyDenied;

  RequestPermissionManager(PermissionType permissionType) {
    _permissionType = permissionType;
  }

  RequestPermissionManager onPermissionDenied(Function()? onPermissionDenied) {
    _onPermissionDenied = onPermissionDenied;
    return this;
  }

  RequestPermissionManager onPermissionGranted(
    Function()? onPermissionGranted,
  ) {
    _onPermissionGranted = onPermissionGranted;
    return this;
  }

  RequestPermissionManager onPermissionPermanentlyDenied(
    Function()? onPermissionPermanentlyDenied,
  ) {
    _onPermissionPermanentlyDenied = onPermissionPermanentlyDenied;
    return this;
  }

  Permission _getPermissionFromType(PermissionType permissionType) {
    switch (permissionType) {
      case PermissionType.microphone:
        return Permission.microphone;
      case PermissionType.camera:
        return Permission.camera;
      case PermissionType.storage:
        return Permission.storage;
      case PermissionType.notification:
        return Permission.notification;
      case PermissionType.location:
        return Permission.location;
      case PermissionType.contacts:
        return Permission.contacts;
      case PermissionType.photos:
        return Permission.photos;
    }
  }

  Future<void> execute() async {
    Permission permission = _getPermissionFromType(_permissionType!);
    PermissionStatus status = await permission.request();

    if (status.isGranted) {
      if (_onPermissionGranted != null) {
        _onPermissionGranted!();
      }
    } else if (status.isDenied) {
      if (_onPermissionDenied != null) {
        _onPermissionDenied!();
      }
    } else if (status.isPermanentlyDenied) {
      if (_onPermissionPermanentlyDenied != null) {
        _onPermissionPermanentlyDenied!();
      }
    }
  }
}
