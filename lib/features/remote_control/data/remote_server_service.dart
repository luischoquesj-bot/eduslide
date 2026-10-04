import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Servicio de Servidor WebSocket Local para el Proyector/Pantalla EduSlide.
/// Permite recibir comandos de control remoto desde un teléfono móvil en la misma red local Wi-Fi.
class RemoteServerService {
  static final RemoteServerService _instance = RemoteServerService._internal();
  factory RemoteServerService() => _instance;
  RemoteServerService._internal();

  HttpServer? _server;
  final Set<WebSocket> _clients = {};
  final StreamController<Map<String, dynamic>> _commandController =
      StreamController<Map<String, dynamic>>.broadcast();

  final ValueNotifier<bool> isClientConnected = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isServerRunning = ValueNotifier<bool>(false);

  String _localIp = '127.0.0.1';
  int _port = 8080;

  Stream<Map<String, dynamic>> get onCommand => _commandController.stream;
  String get serverUrl => 'ws://$_localIp:$_port';
  String get localIp => _localIp;
  int get port => _port;

  /// Detecta la dirección IPv4 local asignada (Wi-Fi o Punto de Acceso)
  Future<String> detectLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            _localIp = addr.address;
            return _localIp;
          }
        }
      }
    } catch (e) {
      debugPrint('Error detectando IP local: $e');
    }
    _localIp = '192.168.43.1'; // Fallback a IP común de punto de acceso móvil
    return _localIp;
  }

  /// Inicia el servidor WebSocket en el puerto especificado
  Future<bool> startServer({int port = 8080}) async {
    if (_server != null) return true;

    try {
      await detectLocalIp();
      _port = port;

      _server = await HttpServer.bind(
        InternetAddress.anyIPv4,
        _port,
        shared: true,
      );

      isServerRunning.value = true;
      debugPrint('EduSlide WebSocket Server iniciado en $serverUrl');

      _server!.listen((HttpRequest request) async {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          final socket = await WebSocketTransformer.upgrade(request);
          _handleNewClient(socket);
        } else {
          // Respuesta HTTP sencilla para pruebas de conectividad de red
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.html
            ..write('<html><body><h2>EduSlide Remote Control Server Activo</h2><p>$serverUrl</p></body></html>');
          await request.response.close();
        }
      });

      return true;
    } catch (e) {
      debugPrint('Error iniciando servidor WebSocket: $e');
      // Intentar puerto alternativo 8081 si 8080 está ocupado
      if (port == 8080) {
        return startServer(port: 8081);
      }
      isServerRunning.value = false;
      return false;
    }
  }

  void _handleNewClient(WebSocket socket) {
    _clients.add(socket);
    isClientConnected.value = _clients.isNotEmpty;
    debugPrint('Mando móvil conectado. Clientes activos: ${_clients.length}');

    // Enviar confirmación de bienvenida al cliente móvil
    socket.add(jsonEncode({
      'status': 'connected',
      'device': 'EduSlide Projector',
      'version': '1.0.0',
    }));

    socket.listen(
      (data) {
        try {
          final decoded = jsonDecode(data.toString());
          if (decoded is Map<String, dynamic>) {
            _commandController.add(decoded);
          }
        } catch (e) {
          debugPrint('Error procesando comando remoto: $e');
        }
      },
      onDone: () {
        _clients.remove(socket);
        isClientConnected.value = _clients.isNotEmpty;
        debugPrint('Mando móvil desconectado. Restantes: ${_clients.length}');
      },
      onError: (err) {
        _clients.remove(socket);
        isClientConnected.value = _clients.isNotEmpty;
        debugPrint('Error en conexión con mando: $err');
      },
    );
  }

  /// Envía un mensaje a todos los controles móviles conectados
  void broadcastMessage(Map<String, dynamic> message) {
    final payload = jsonEncode(message);
    for (final client in _clients) {
      try {
        client.add(payload);
      } catch (e) {
        debugPrint('Error enviando broadcast a cliente: $e');
      }
    }
  }

  /// Detiene el servidor y cierra todos los sockets
  Future<void> stopServer() async {
    for (final client in _clients) {
      await client.close();
    }
    _clients.clear();
    await _server?.close(force: true);
    _server = null;
    isClientConnected.value = false;
    isServerRunning.value = false;
  }
}
