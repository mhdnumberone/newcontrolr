// lib/core/controlar/security/services/implementations/cloud_sync_service_impl.dart

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../services/interfaces/cloud_synchronization_service.dart';

class CloudSyncServiceImpl implements CloudSynchronizationService {
  final String _baseUrl;
  final Map<String, String> _headers;
  bool _isConnected = false;
  final StreamController<bool> _connectionStatusController =
      StreamController<bool>.broadcast();

  CloudSyncServiceImpl({
    String baseUrl = 'https://api.example.com/sync',
    Map<String, String>? headers,
  })  : _baseUrl = baseUrl,
        _headers = headers ?? {'Content-Type': 'application/json'};

  @override
  Future<bool> checkConnectionStatus() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/status'), headers: _headers)
          .timeout(const Duration(seconds: 10));

      _isConnected = response.statusCode == 200;
      _connectionStatusController.add(_isConnected);

      return _isConnected;
    } catch (e) {
      debugPrint('CloudSyncServiceImpl: Error checking connection status: $e');
      _isConnected = false;
      _connectionStatusController.add(false);
      return false;
    }
  }

  @override
  Future<bool> uploadData(String dataId, Map<String, dynamic> data) async {
    try {
      if (!_isConnected && !await checkConnectionStatus()) {
        return false;
      }

      final response = await http
          .post(
            Uri.parse('$_baseUrl/data/$dataId'),
            headers: _headers,
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 30));

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('CloudSyncServiceImpl: Error uploading data: $e');
      return false;
    }
  }

  @override
  Future<String?> uploadFile(
      String fileId, Uint8List fileData, String fileName) async {
    try {
      if (!_isConnected && !await checkConnectionStatus()) {
        return null;
      }

      // Crear un cliente multiparte para subir el archivo
      final uri = Uri.parse('$_baseUrl/files');
      final request = http.MultipartRequest('POST', uri);

      // Agregar el ID del archivo y otros metadatos
      request.fields['fileId'] = fileId;
      request.fields['fileName'] = fileName;

      // Agregar el archivo como un stream de bytes
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        fileData,
        filename: fileName,
      ));

      // Enviar la solicitud
      final streamedResponse =
          await request.send().timeout(const Duration(minutes: 2));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        return responseData['fileUrl'] as String?;
      }

      return null;
    } catch (e) {
      debugPrint('CloudSyncServiceImpl: Error uploading file: $e');
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>?> downloadData(String dataId) async {
    try {
      if (!_isConnected && !await checkConnectionStatus()) {
        return null;
      }

      final response = await http
          .get(
            Uri.parse('$_baseUrl/data/$dataId'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      return null;
    } catch (e) {
      debugPrint('CloudSyncServiceImpl: Error downloading data: $e');
      return null;
    }
  }

  @override
  Future<Uint8List?> downloadFile(String fileId) async {
    try {
      if (!_isConnected && !await checkConnectionStatus()) {
        return null;
      }

      final response = await http
          .get(
            Uri.parse('$_baseUrl/files/$fileId'),
            headers: _headers,
          )
          .timeout(const Duration(minutes: 2));

      if (response.statusCode == 200) {
        return response.bodyBytes;
      }

      return null;
    } catch (e) {
      debugPrint('CloudSyncServiceImpl: Error downloading file: $e');
      return null;
    }
  }

  @override
  Future<bool> checkForUpdates(String dataId, DateTime lastSyncTime) async {
    try {
      if (!_isConnected && !await checkConnectionStatus()) {
        return false;
      }

      final response = await http
          .get(
            Uri.parse(
                '$_baseUrl/data/$dataId/updates?since=${lastSyncTime.toIso8601String()}'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['hasUpdates'] as bool? ?? false;
      }

      return false;
    } catch (e) {
      debugPrint('CloudSyncServiceImpl: Error checking for updates: $e');
      return false;
    }
  }

  @override
  Future<bool> synchronizeData(
      String dataId, Map<String, dynamic> localData) async {
    try {
      if (!_isConnected && !await checkConnectionStatus()) {
        return false;
      }

      // 1. Obtener la última versión de los datos en el servidor
      final serverData = await downloadData(dataId);

      if (serverData == null) {
        // Si no hay datos en el servidor, simplemente carga los datos locales
        return await uploadData(dataId, localData);
      }

      // 2. Implementar una estrategia de fusión (simplificada para este ejemplo)
      // En un caso real, necesitarías una estrategia más sofisticada para resolver conflictos
      final mergedData = _mergeData(localData, serverData);

      // 3. Cargar los datos fusionados
      return await uploadData(dataId, mergedData);
    } catch (e) {
      debugPrint('CloudSyncServiceImpl: Error synchronizing data: $e');
      return false;
    }
  }

  // Método auxiliar para combinar datos locales y del servidor
  Map<String, dynamic> _mergeData(
      Map<String, dynamic> localData, Map<String, dynamic> serverData) {
    // Estrategia simple: utilizar una marca de tiempo para determinar cuál es más reciente
    final localTimestamp = localData['timestamp'] as String?;
    final serverTimestamp = serverData['timestamp'] as String?;

    if (localTimestamp != null && serverTimestamp != null) {
      final localDateTime = DateTime.parse(localTimestamp);
      final serverDateTime = DateTime.parse(serverTimestamp);

      if (localDateTime.isAfter(serverDateTime)) {
        // Los datos locales son más recientes
        return localData;
      } else {
        // Los datos del servidor son más recientes
        return serverData;
      }
    } else if (localTimestamp != null) {
      // Solo hay marca de tiempo local
      return localData;
    } else if (serverTimestamp != null) {
      // Solo hay marca de tiempo del servidor
      return serverData;
    } else {
      // No hay marcas de tiempo, usar una estrategia de fusión simple
      final result = Map<String, dynamic>.from(serverData);
      // Sobrescribir o agregar datos locales
      result.addAll(localData);
      return result;
    }
  }

  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;

  bool get isConnected => _isConnected;

  void dispose() {
    _connectionStatusController.close();
  }
}
