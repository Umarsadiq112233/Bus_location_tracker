class NotificationRepository {
  Future<List<String>> latestNotifications() async {
    return ['Bus started trip', 'Bus near pickup point'];
  }
}
