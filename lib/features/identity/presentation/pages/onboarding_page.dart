import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
            title: 'Your NeoShare Code',
            body: Center(child: CircularProgressIndicator.adaptive()),
          );
        }

        if (state is IdentityProvisioned) {
          return PlatformScaffold(
            title: 'Your NeoShare Code',
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      ShortCodeUtil.formatForDisplay(state.user.shortCode),
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                          ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Share this code with others to receive files.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    PlatformActionButton(
                      label: 'Copy Code',
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: state.user.shortCode),
                        );
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
            ),
          );
        }

        if (state is IdentityError) {
          return PlatformScaffold(
            title: 'Your NeoShare Code',
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
          title: 'Your NeoShare Code',
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
