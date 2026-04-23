import 'dart:async';

import 'package:cookie_auth_client/cookie_auth_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

const _apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8000',
);
const _csrfCookieName = 'example_csrf_token';
const _exampleVersion = '0.1.1';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dio = Dio(
    BaseOptions(
      baseUrl: _apiBaseUrl,
      headers: const {'Accept': 'application/json'},
    ),
  );
  final authDio = CookieAuthDio(
    dio,
    csrfCookieName: _csrfCookieName,
  );
  final authApi = DioCookieAuthApi(
    dio,
    csrfCookieName: _csrfCookieName,
  );
  final userService = ExampleUserService(dio);
  final authController = ExampleAuthController(
    authApi: authApi,
    authDio: authDio,
    userService: userService,
  );

  runApp(
    ExampleApp(
      authController: authController,
      userService: userService,
    ),
  );
  unawaited(authController.restoreSession());
}

class ExampleUser {
  const ExampleUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
  });

  factory ExampleUser.fromJson(Map<String, dynamic> json) {
    return ExampleUser(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String,
      role: json['role'] as String,
    );
  }

  final String id;
  final String email;
  final String displayName;
  final String role;
}

class ExampleUserService {
  ExampleUserService(this._dio);

  final Dio _dio;

  Future<ExampleUser> getMe() async {
    final response = await _dio.get('/users/me');
    return ExampleUser.fromJson(_asJsonMap(response.data));
  }
}

class ExampleAuthController extends CookieAuthController<ExampleUser> {
  ExampleAuthController({
    required super.authApi,
    required super.authDio,
    required this.userService,
  }) : super(loadCurrentUser: userService.getMe);

  final ExampleUserService userService;

  bool get isFarmAdmin => currentUser?.role == 'farm-admin';
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({
    required this.authController,
    required this.userService,
    super.key,
  });

  final ExampleAuthController authController;
  final ExampleUserService userService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'cookie_auth_client example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8E4B23),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5E8D5),
      ),
      home: AuthHomePage(
        authController: authController,
        userService: userService,
      ),
    );
  }
}

class AuthHomePage extends StatefulWidget {
  const AuthHomePage({
    required this.authController,
    required this.userService,
    super.key,
  });

  final ExampleAuthController authController;
  final ExampleUserService userService;

  @override
  State<AuthHomePage> createState() => _AuthHomePageState();
}

class _AuthHomePageState extends State<AuthHomePage> {
  final _emailController = TextEditingController(text: 'demo@example.com');
  final _passwordController = TextEditingController(text: 'demo-password');

  String? _statusMessage;
  String? _requestMessage;

  @override
  void initState() {
    super.initState();
    widget.authController.addListener(_handleAuthChange);
  }

  @override
  void dispose() {
    widget.authController.removeListener(_handleAuthChange);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleAuthChange() {
    final notice = widget.authController.consumeNotice();
    if (notice == AuthNotice.sessionExpired && mounted) {
      setState(() {
        _statusMessage = 'Session expired. Sign in again to continue.';
      });
    }
  }

  Future<void> _login() async {
    setState(() {
      _statusMessage = 'Signing in...';
    });

    try {
      await widget.authController.login(
        _emailController.text,
        _passwordController.text,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage =
            'Signed in as ${widget.authController.currentUser?.displayName}.';
        _requestMessage = null;
      });
      _passwordController.selection = TextSelection.collapsed(
        offset: _passwordController.text.length,
      );
    } on AuthFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = switch (error.reason) {
          AuthFailureReason.invalidCredentials =>
            'Invalid email or password.',
          AuthFailureReason.unavailable => 'The auth service is unavailable.',
        };
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = 'Unexpected login failure.';
      });
    }
  }

  Future<void> _loadProtectedProfile() async {
    setState(() {
      _requestMessage = 'Loading /users/me with the shared Dio client...';
    });

    try {
      final user = await widget.userService.getMe();
      widget.authController.updateCurrentUser(user);
      if (!mounted) {
        return;
      }
      setState(() {
        _requestMessage =
            'Protected request succeeded at ${_formatTime(DateTime.now())}.';
      });
    } on DioException catch (error) {
      if (!mounted) {
        return;
      }
      final statusCode = error.response?.statusCode;
      setState(() {
        _requestMessage = statusCode == null
            ? 'Protected request failed before a response was returned.'
            : 'Protected request failed with HTTP $statusCode.';
      });
    }
  }

  Future<void> _logout() async {
    setState(() {
      _statusMessage = 'Signing out...';
    });
    await widget.authController.logout();
    if (!mounted) {
      return;
    }
    setState(() {
      _statusMessage = 'Local session cleared.';
      _requestMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.authController,
      builder: (context, _) {
        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF5E8D5),
                  Color(0xFFE4D2B7),
                  Color(0xFFD0E0D3),
                ],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: Wrap(
                      spacing: 24,
                      runSpacing: 24,
                      children: [
                        _heroCard(),
                        _authCard(),
                        _sessionCard(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _heroCard() {
    return SizedBox(
      width: 440,
      child: Card(
        elevation: 0,
        color: const Color(0xFF173F35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE4D2B7),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'cookie_auth_client v0.1.1',
                  style: TextStyle(
                    color: Color(0xFF173F35),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'First-party auth flow with in-memory access tokens and refresh cookies.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'API base URL: $_apiBaseUrl\nExample version: $_exampleVersion',
                style: const TextStyle(
                  color: Color(0xFFE4D2B7),
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Sign in, wait for the one-minute access token to expire, then reload /users/me to watch CookieAuthDio refresh the session and retry the protected request once.',
                style: TextStyle(
                  color: Color(0xFFD9F1E0),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _authCard() {
    final controller = widget.authController;
    final isBusy = controller.isLoading || controller.isRestoringSession;

    return SizedBox(
      width: 440,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: controller.isRestoringSession
              ? const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Restoring session',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 16),
                    LinearProgressIndicator(minHeight: 8),
                    SizedBox(height: 16),
                    Text(
                      'The controller is calling /auth/refresh and then /users/me if a refresh cookie is present.',
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sign in',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'These fields are prefilled with the demo credentials from the FastAPI example app.',
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: isBusy ? null : _login,
                            child: const Text('Login'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isBusy ? null : _logout,
                            child: const Text('Logout'),
                          ),
                        ),
                      ],
                    ),
                    if (_statusMessage != null) ...[
                      const SizedBox(height: 18),
                      Text(
                        _statusMessage!,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  Widget _sessionCard() {
    final controller = widget.authController;
    final user = controller.currentUser;

    return SizedBox(
      width: 440,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Session view',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                controller.isAuthenticated
                    ? 'The app-specific controller has a current user and an in-memory access token.'
                    : 'No authenticated user is loaded yet.',
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F3EC),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  user == null
                      ? 'currentUser: null'
                      : 'currentUser:\n'
                          '  id: ${user.id}\n'
                          '  email: ${user.email}\n'
                          '  display_name: ${user.displayName}\n'
                          '  role: ${user.role}\n'
                          '  isFarmAdmin: ${controller.isFarmAdmin}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.tonalIcon(
                onPressed: controller.isAuthenticated
                    ? _loadProtectedProfile
                    : null,
                icon: const Icon(Icons.sync),
                label: const Text('Reload /users/me'),
              ),
              if (_requestMessage != null) ...[
                const SizedBox(height: 14),
                Text(
                  _requestMessage!,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Map<String, dynamic> _asJsonMap(Object? data) {
  if (data is Map<String, dynamic>) {
    return data;
  }
  if (data is Map) {
    return Map<String, dynamic>.from(data);
  }
  throw StateError('Expected a JSON object response.');
}

String _formatTime(DateTime time) {
  final hours = time.hour.toString().padLeft(2, '0');
  final minutes = time.minute.toString().padLeft(2, '0');
  final seconds = time.second.toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}
