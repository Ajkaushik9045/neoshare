import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/service_locator.dart';
import '../bloc/inbox_bloc.dart';
import '../../domain/entities/transfer.dart';
import '../../domain/entities/transfer_file.dart';

class InboxPage extends StatelessWidget {
  const InboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => sl<InboxBloc>()..add(const InboxStarted()),
      child: const _InboxView(),
    );
  }
}

class _InboxView extends StatelessWidget {
  const _InboxView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inbox')),
      body: BlocBuilder<InboxBloc, InboxState>(
        builder: (context, state) => switch (state) {
          InboxInitial() ||
          InboxLoading() => const Center(child: CircularProgressIndicator()),

          InboxError(:final message) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () =>
                      context.read<InboxBloc>().add(const InboxStarted()),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),

          InboxLoaded(transfers: final transfers) when transfers.isEmpty =>
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No incoming transfers',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),

          InboxLoaded(
            :final transfers,
            :final activeDownloads,
            :final savedFileIds,
            :final savedTransferIds,
            :final errors,
          ) =>
            ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: transfers.length,
              itemBuilder: (ctx, i) => _TransferCard(
                transfer: transfers[i],
                activeDownloads: activeDownloads,
                savedFileIds: savedFileIds,
                savedTransferIds: savedTransferIds,
                error: errors[transfers[i].transferId],
              ),
            ),
        },
      ),
    );
  }
}

// ─── Transfer Card ──────────────────────────────────────────────────────────

class _TransferCard extends StatelessWidget {
  final Transfer transfer;
  final Set<String> activeDownloads;
  final Set<String> savedFileIds;
  final Set<String> savedTransferIds;
  final String? error;

  const _TransferCard({
    required this.transfer,
    required this.activeDownloads,
    required this.savedFileIds,
    required this.savedTransferIds,
    required this.error,
  });

  bool get _allSaved => savedTransferIds.contains(transfer.transferId);
  bool get _batchActive => activeDownloads.contains(transfer.transferId);

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.download_for_offline_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'From: ${transfer.senderCode}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        _formatDate(transfer.createdAt),
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.black45),
                      ),
                    ],
                  ),
                ),
                _BatchDownloadWidget(
                  transfer: transfer,
                  allSaved: _allSaved,
                  batchActive: _batchActive,
                ),
              ],
            ),

            // ── Batch progress bar ─────────────────────────────────────
            if (_batchActive) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: transfer.totalProgress > 0
                    ? transfer.totalProgress
                    : null,
              ),
              const SizedBox(height: 4),
              Text(
                'Saving to Downloads via MediaStore…',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],

            const Divider(height: 20),

            // ── Per-file rows ──────────────────────────────────────────
            ...transfer.files.map(
              (f) => _FileRow(
                file: f,
                transferId: transfer.transferId,
                isSaved: savedFileIds.contains(f.fileId),
                isActive: activeDownloads.contains(
                  '${transfer.transferId}_${f.fileId}',
                ),
              ),
            ),

            // ── Error ──────────────────────────────────────────────────
            if (error != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BatchDownloadWidget extends StatelessWidget {
  final Transfer transfer;
  final bool allSaved;
  final bool batchActive;

  const _BatchDownloadWidget({
    required this.transfer,
    required this.allSaved,
    required this.batchActive,
  });

  @override
  Widget build(BuildContext context) {
    if (allSaved) {
      return const Chip(
        avatar: Icon(Icons.check_circle, size: 16, color: Colors.green),
        label: Text('Saved'),
        visualDensity: VisualDensity.compact,
      );
    }
    if (batchActive) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return TextButton.icon(
      icon: const Icon(Icons.download_rounded, size: 18),
      label: const Text('Save All'),
      onPressed: () =>
          context.read<InboxBloc>().add(DownloadRequested(transfer.transferId)),
    );
  }
}

// ─── File Row ───────────────────────────────────────────────────────────────

class _FileRow extends StatelessWidget {
  final TransferFile file;
  final String transferId;
  final bool isSaved;
  final bool isActive;

  const _FileRow({
    required this.file,
    required this.transferId,
    required this.isSaved,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(_mimeIcon(file.mimeType), size: 20, color: Colors.blueGrey),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(file.name, overflow: TextOverflow.ellipsis),
                if (isActive)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: LinearProgressIndicator(
                      value: file.progress > 0 ? file.progress : null,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Status / action
          if (isActive)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (isSaved)
            const Tooltip(
              message: 'Saved to Downloads',
              child: Icon(Icons.check_circle, color: Colors.green, size: 22),
            )
          else
            Tooltip(
              message: 'Save this file via MediaStore',
              child: IconButton(
                icon: const Icon(Icons.download_rounded, size: 22),
                onPressed: () => context.read<InboxBloc>().add(
                  DownloadFileRequested(transferId, file.fileId),
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _mimeIcon(String mimeType) {
    if (mimeType.startsWith('image/')) return Icons.image_outlined;
    if (mimeType.startsWith('video/')) return Icons.videocam_outlined;
    if (mimeType.startsWith('audio/')) return Icons.audiotrack_outlined;
    if (mimeType.contains('pdf')) return Icons.picture_as_pdf_outlined;
    if (mimeType.contains('zip') || mimeType.contains('archive'))
      return Icons.folder_zip_outlined;
    return Icons.insert_drive_file_outlined;
  }
}
