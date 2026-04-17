import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/utils/short_code_util.dart';
import '../../../identity/data/datasources/local_identity_ds.dart';
import '../../../../shared/platform/platform_action_button.dart';
import '../../../../shared/platform/platform_scaffold.dart';
import '../../../../shared/widgets/app_platform_dialog.dart';
import '../../../../shared/widgets/app_scaffold_messenger.dart';
import '../../../../shared/widgets/short_code_input_formatter.dart';
import '../bloc/send_bloc.dart';

/// Send page with short-code validation and recipient lookup flow.
class SendPage extends StatefulWidget {
  const SendPage({super.key});

  @override
  State<SendPage> createState() => _SendPageState();
}

class _SendPageState extends State<SendPage> {
  final TextEditingController _recipientCodeController = TextEditingController();

  @override
  void dispose() {
    _recipientCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SendBloc>(
      create: (_) => sl<SendBloc>(),
      child: BlocConsumer<SendBloc, SendState>(
        listener: (context, state) async {
          if (state is SendError) {
            if (state.message == 'You cannot send files to yourself') {
              await AppPlatformDialog.showMessage(
                context: context,
                title: "It's you",
                message: state.message,
              );
              return;
            }
            AppScaffoldMessenger.showError(context, state.message);
          }

          if (state is SendSuccess) {
            AppScaffoldMessenger.showInfo(
              context,
              'Recipient found. Ready to send files.',
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is SendLoading;
          return PlatformScaffold(
            title: 'NeoShare',
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),
                  Text(
                    'Send Files',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter recipient code to verify the user before sending.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.black54,
                        ),
                  ),
                  const SizedBox(height: 26),
                  TextField(
                    controller: _recipientCodeController,
                    maxLength: 6,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: <TextInputFormatter>[
                      ShortCodeInputFormatter(),
                    ],
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          letterSpacing: 3,
                          fontWeight: FontWeight.w700,
                        ),
                    decoration: InputDecoration(
                      labelText: 'Recipient code',
                      hintText: 'A4X9K2',
                      filled: true,
                      fillColor: const Color(0xFFF6F8FF),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFD4DEFF)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFD4DEFF)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF5A78FF), width: 1.8),
                      ),
                      counterText: '',
                    ),
                    enabled: !isLoading,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter exactly 6 characters.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.black45,
                        ),
                  ),
                  const Spacer(),
                  if (isLoading)
                    const Center(child: CircularProgressIndicator.adaptive()),
                ],
              ),
            ),
            bottomBar: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                child: PlatformActionButton(
                  label: isLoading ? 'Checking...' : 'Send Files',
                  isExpanded: true,
                  height: 58,
                  onPressed: isLoading ? null : () => _submit(context),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _submit(BuildContext context) {
    final normalizedRecipientCode = ShortCodeUtil.normalize(_recipientCodeController.text);
    if (normalizedRecipientCode.length != 6) {
      AppScaffoldMessenger.showError(
        context,
        'Short code must be exactly 6 characters.',
      );
      return;
    }

    final currentUser = sl<LocalIdentityDataSource>().getCachedUser();
    if (currentUser == null) {
      AppScaffoldMessenger.showError(
        context,
        'Your identity is not ready yet. Please reopen onboarding.',
      );
      return;
    }

    context.read<SendBloc>().add(
          SendRequested(
            senderShortCode: currentUser.shortCode,
            recipientShortCode: normalizedRecipientCode,
          ),
        );
  }
}
