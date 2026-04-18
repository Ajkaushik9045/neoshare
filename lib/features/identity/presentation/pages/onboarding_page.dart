import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:go_router/go_router.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/utils/short_code_util.dart';
import '../../../../shared/platform/platform_action_button.dart';
import '../../../../shared/platform/platform_scaffold.dart';
import '../../../../shared/widgets/app_scaffold_messenger.dart';
import '../bloc/identity_bloc.dart';

/// Single-screen onboarding that provisions and displays the user's short code.
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<IdentityBloc, IdentityState>(
      listener: (context, state) {
        if (state is IdentityError) {
          AppScaffoldMessenger.showError(context, state.message);
        }
      },
      builder: (context, state) {
        if (state is IdentityLoading) {
          return const PlatformScaffold(
            title: 'NeoShare',
            body: _LoadingView(),
          );
        }

        if (state is IdentityProvisioned) {
          return PlatformScaffold(
            title: 'NeoShare',
            body: _IdentityBody(shortCode: state.user.shortCode),
            bottomBar: _BottomBarButton(
              text: 'Send Files',
              onPressed: () {
                sl<GoRouter>().go('/send');
              },
            ),
          );
        }

        if (state is IdentityError) {
          return PlatformScaffold(
            title: 'NeoShare',
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: PlatformActionButton(
                  label: 'Retry Provisioning',
                  onPressed: () {
                    context.read<IdentityBloc>().add(const IdentityProvisionRequested());
                  },
                ),
              ),
            ),
          );
        }

        return PlatformScaffold(
          title: 'NeoShare',
          body: Center(
            child: PlatformActionButton(
              label: 'Create My Code',
              onPressed: () {
                context.read<IdentityBloc>().add(const IdentityProvisionRequested());
              },
            ),
          ),
        );
      },
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator.adaptive());
  }
}

class _IdentityBody extends StatelessWidget {
  const _IdentityBody({required this.shortCode});

  final String shortCode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Text(
            'Your NeoShare Code',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Share this code to receive files securely.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.black54,
                ),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F8FF),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFD4DEFF)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  ShortCodeUtil.formatForDisplay(shortCode),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 5,
                      ),
                ),
                const SizedBox(height: 18),
                PlatformActionButton(
                  label: 'Copy Code',
                  isExpanded: true,
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: shortCode));
                    if (context.mounted) {
                      AppScaffoldMessenger.showInfo(
                        context,
                        'Code copied to clipboard.',
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _BottomBarButton extends StatelessWidget {
  const _BottomBarButton({
    required this.text,
    required this.onPressed,
  });

  final String text;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        child: PlatformActionButton(
          label: text,
          isExpanded: true,
          height: 58,
          onPressed: onPressed,
        ),
      ),
    );
  }
}
