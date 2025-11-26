import '../services/api_client.dart';

class MonitoringService {
  final ApiClient _client;

  MonitoringService(this._client);

  Future<bool> getMonitoringEnabled() async {
    return await _client.getMonitoringEnabled();
  }

  Future<bool> setMonitoringEnabled(bool enabled) async {
    return await _client.setMonitoringEnabled(enabled);
  }

  Future<int> getMonitoringInterval() async {
    return await _client.getMonitoringInterval();
  }

  Future<int?> setMonitoringInterval(int seconds) async {
    return await _client.setMonitoringInterval(seconds);
  }
}
