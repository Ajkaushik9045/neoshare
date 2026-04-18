import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/platform/file_api.g.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/short_code_util.dart';
import '../../../identity/data/datasources/local_identity_ds.dart';
import '../../../../shared/platform/platform_action_button.dart';
import '../../../../shared/platform/platform_scaffold.dart';
import '../../../../shared/widgets/app_platform_dialog.dart';
import '../../../../shared/widgets/app_platform_indicator.dart';
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
          if (state is RecipientNotFound) {
            if (state.reason == 'You cannot send files to yourself') {
              await AppPlatformDialog.showMessage(
                context: context,
                title: "It's you",
                message: state.reason,
              );
            } else {
              AppScaffoldMessenger.showError(context, state.reason);
            }
          } else if (state is UploadFailed) {
            if (state.reason.contains('500 MB')) {
              await AppPlatformDialog.showMessage(
                context: context,
                title: 'File Too Large',
                message: state.reason,
              );
            } else {
              AppScaffoldMessenger.showError(context, state.reason);
            }
          } else if (state is RecipientFound) {
            AppScaffoldMessenger.showInfo(
              context,
              'Recipient found. Select files to send.',
            );

            AppLogger.step('Opening native file picker via Pigeon FileHostApi.pickFiles()');
            List<PickedFileInfo> picked = [];
            try {
              picked = await FileHostApi().pickFiles();
            } catch (e) {
              AppLogger.error('Pigeon pickFiles() threw', data: e.toString());
              if (context.mounted) AppScaffoldMessenger.showError(context, 'Could not open file picker.');
              return;
            }
            AppLogger.success('Pigeon pickFiles() returned ${picked.length} file(s)');
            if (!context.mounted) return;

            if (picked.isNotEmpty) {
              context.read<SendBloc>().add(FilesChosen(picked));
            }
          } else if (state is FilesSelected && state.isMetered) {
             final proceed = await showDialog<bool>(
               context: context,
               builder: (ctx) => AlertDialog(
                 title: const Text('Metered Connection'),
                 content: const Text('You are on a metered connection. Proceed to send?'),
                 actions: [
                   TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                   TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continue')),
                 ],
               ),
             );
             if (!context.mounted) return;
             
             if (proceed == true) {
               context.read<SendBloc>().add(const UploadConfirmed());
             }
          } else if (state is UploadComplete) {
            AppScaffoldMessenger.showInfo(context, 'Transfer completed!');
            context.go('/');
          }
        },
        builder: (context, state) {
          final isLoading = state is LookingUpRecipient || state is Uploading || state is PreparingUpload;
          final isUploading = state is Uploading;
          final isPreparing = state is PreparingUpload;
          
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
                  if (!isUploading) const Spacer(),
                  if (isUploading) ...[
                    const SizedBox(height: 16),
                    Text('Total Progress: ${((state as Uploading).totalProgress * 100).toStringAsFixed(1)}%'),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(value: (state as Uploading).totalProgress, minHeight: 8),
                    const SizedBox(height: 20),
                    const Text('Files:', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.separated(
                        itemCount: (state as Uploading).fileProgress.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final st = state as Uploading;
                          final keys = st.fileProgress.keys.toList();
                          final fileName = keys[index];
                          final prog = st.fileProgress[fileName] ?? 0.0;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis)),
                                  const SizedBox(width: 8),
                                  Text('${(prog * 100).toStringAsFixed(1)}%'),
                                ],
                              ),
                              const SizedBox(height: 6),
                              LinearProgressIndicator(value: prog),
                            ],
                          );
                        },
                      ),
                    ),
                  ] else if (isLoading)
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const AppPlatformIndicator(),
                          if (isPreparing) ...[
                            const SizedBox(height: 12),
                            const Text('Checking files...'),
                          ]
                        ],
                      ),
                    ),
                ],
              ),
            ),
            bottomBar: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                child: PlatformActionButton(
                  label: isUploading ? 'Uploading...' : 'Send Files',
                  isExpanded: true,
                  height: 58,
                  isLoading: isLoading && !isUploading,
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
          LookupRecipient(
            senderShortCode: currentUser.shortCode,
            recipientShortCode: normalizedRecipientCode,
          ),
        );
  }
}
