# Flutter Integration Notes

The Flutter package owns generic session mechanics. Your app owns users, roles,
route redirects, and UI state.

## Basic Setup

```dart
final dio = Dio(BaseOptions(baseUrl: '/api'));
final authDio = CookieAuthDio(
  dio,
  csrfCookieName: 'app_csrf_token',
);
final authApi = DioCookieAuthApi(
  dio,
  csrfCookieName: 'app_csrf_token',
);

final auth = CookieAuthController<AppUser>(
  authApi: authApi,
  authDio: authDio,
  loadCurrentUser: () => userService.getMe(),
);

await auth.restoreSession();
```

## App Provider Pattern

For real apps, wrap the generic controller:

```dart
class AppAuthProvider extends CookieAuthController<AppUser> {
  AppAuthProvider({
    required CookieAuthApi authApi,
    required CookieAuthDio authDio,
    required UserService userService,
  }) : super(
         authApi: authApi,
         authDio: authDio,
         loadCurrentUser: userService.getMe,
       );

  bool get isAdmin => currentUser?.role == 'admin';
}
```

## Migration Checklist

- Add `cookie_auth_client`.
- Use one shared Dio client for API calls.
- Create `CookieAuthDio`.
- Create `CookieAuthApi` or adapt your existing API package.
- Extend `CookieAuthController<AppUser>`.
- Call `restoreSession()` during app boot.
- Route unauthenticated users to login.
- Keep role/dashboard logic in the consuming app.
