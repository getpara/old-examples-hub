// ignore_for_file: unused_field, unused_local_variable

import 'package:cpsl_flutter/widgets/demo_home.dart';
import 'package:cpsl_flutter/widgets/oauth_browser.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:capsule/capsule.dart';
import 'package:cpsl_flutter/client/capsule.dart';

class CapsuleOAuthExample extends StatefulWidget {
  const CapsuleOAuthExample({super.key});

  @override
  State<CapsuleOAuthExample> createState() => _CapsuleOAuthExampleState();
}

class _CapsuleOAuthExampleState extends State<CapsuleOAuthExample> {
  bool _isLoading = false;
  String? _loadingProvider;
  Wallet? _wallet;
  String? _address;
  String? _recoveryShare;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    try {
      final isLoggedIn = await capsuleClient.isFullyLoggedIn();
      if (isLoggedIn && mounted) {
        final wallets = await capsuleClient.getWallets();

        if (wallets.isNotEmpty) {
          setState(() {
            _wallet = wallets.values.first;
            _address = wallets.values.first.address;
            _recoveryShare = "";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking login status: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _handleOAuthLogin(OAuthMethod provider) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _loadingProvider = provider.value;
    });

    try {
      final oauthUrl = await capsuleClient.getOAuthURL(provider);
      final oauthFuture = capsuleClient.waitForOAuth();

// Google policy restricts webviews for OAuth, so we need to use a custom user agent to bypass it.
      String? googleUserAgent;
      if (provider == OAuthMethod.google) {
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          googleUserAgent = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
              'AppleWebKit/605.1.15 (KHTML, like Gecko) '
              'CriOS/119.0.6045.109 Mobile/15E148 Safari/604.1';
        } else if (defaultTargetPlatform == TargetPlatform.android) {
          googleUserAgent = 'Mozilla/5.0 (Linux; Android 13; Pixel 6) '
              'AppleWebKit/537.36 (KHTML, like Gecko) '
              'Chrome/119.0.6045.109 Mobile Safari/537.36';
        }
      }

      if (!mounted) return;

// This example use a bottom sheet to display a custom OAuth browser that wraps the flutter_inappwebview. If using this library as the webview to launch the OAuth URL check the OAuthBrowser widget implementation.
      bool webViewClosed = false;
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        isDismissible: true,
        enableDrag: false,
        builder: (BuildContext context) => OAuthBrowser(
          url: oauthUrl,
          providerName: provider.value,
          userAgent: googleUserAgent,
          onBrowserClosed: (closed) async {
            webViewClosed = closed;
            if (closed) {
              await capsuleClient.cancelOperation('waitForOAuth');
            }
          },
        ),
      );

      if (webViewClosed) return;

      final oauthResult = await oauthFuture;

      if (!mounted) return;

      if (oauthResult.isError == true) {
        throw Exception('OAuth authentication failed');
      }

      if (oauthResult.userExists) {
        await _handlePasskeyLogin();
        return;
      }

      if (oauthResult.email == null) {
        throw Exception('Email is required for new user registration');
      }

      final biometricsId = await capsuleClient.verifyOAuth();
      await capsuleClient.generatePasskey(oauthResult.email!, biometricsId);
      final result = await capsuleClient.createWallet(skipDistribute: false);

      if (!mounted) return;

      setState(() {
        _wallet = result.wallet;
        _address = result.wallet.address;
        _recoveryShare = result.recoveryShare;
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DemoHome()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingProvider = null;
        });
      }
    }
  }

  Future<void> _handlePasskeyLogin() async {
    setState(() => _isLoading = true);

    try {
      final wallet = await capsuleClient.login();

      if (!mounted) return;

      setState(() {
        _wallet = wallet;
        _address = wallet.address;
        _recoveryShare = "";
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DemoHome()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildOAuthButton({
    required OAuthMethod provider,
    required String label,
    required IconData icon,
    required Color backgroundColor,
    required Color textColor,
  }) {
    final isLoading = _isLoading && _loadingProvider == provider.value;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ElevatedButton(
        onPressed: _isLoading ? null : () => _handleOAuthLogin(provider),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          elevation: 1,
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 16,
          ),
        ),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Continue with $label',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (isLoading)
              const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OAuth Example'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'OAuth Authentication',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Example implementation of OAuth authentication using Capsule SDK with various providers.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 48),
              _buildOAuthButton(
                provider: OAuthMethod.google,
                label: 'Google',
                icon: FontAwesomeIcons.google,
                backgroundColor: const Color(0xFF4285F4),
                textColor: Colors.white,
              ),
              _buildOAuthButton(
                provider: OAuthMethod.apple,
                label: 'Apple',
                icon: FontAwesomeIcons.apple,
                backgroundColor: Colors.white,
                textColor: Colors.black87,
              ),
              _buildOAuthButton(
                provider: OAuthMethod.twitter,
                label: 'X.com',
                icon: FontAwesomeIcons.xTwitter,
                backgroundColor: const Color(0xFF1DA1F2),
                textColor: Colors.white,
              ),
              _buildOAuthButton(
                provider: OAuthMethod.discord,
                label: 'Discord',
                icon: FontAwesomeIcons.discord,
                backgroundColor: const Color(0xFF5865F2),
                textColor: Colors.white,
              ),
              const SizedBox(height: 32),
              // const Row(
              //   children: [
              //     Expanded(child: Divider()),
              //     Padding(
              //       padding: EdgeInsets.symmetric(horizontal: 16),
              //       child: Text(
              //         'OR',
              //         style: TextStyle(
              //           color: Colors.grey,
              //           fontWeight: FontWeight.w500,
              //         ),
              //       ),
              //     ),
              //     Expanded(child: Divider()),
              //   ],
              // ),
              // const SizedBox(height: 32),
              // OutlinedButton(
              //   onPressed: _isLoading ? null : _handlePasskeyLogin,
              //   style: OutlinedButton.styleFrom(
              //     side: BorderSide(
              //       color: Theme.of(context).colorScheme.primary,
              //     ),
              //   ),
              //   child: _isLoading
              //       ? const SizedBox(
              //           height: 20,
              //           width: 20,
              //           child: CircularProgressIndicator(strokeWidth: 2),
              //         )
              //       : const Text('Login with Passkey'),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}
