class AccessToken {
  const AccessToken({required this.value, this.tokenType = 'bearer'});

  final String value;
  final String tokenType;
}
