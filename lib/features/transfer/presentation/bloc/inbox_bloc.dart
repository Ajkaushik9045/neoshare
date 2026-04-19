import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/utils/app_logger.dart';
import '../../data/datasources/local_transfer_ds.dart';
import '../../domain/entities/transfer.dart';
import '../../domain/entities/transfer_file.dart';
import '../../domain/usecases/watch_incoming_transfers.dart';
import '../../domain/usecases/download_transfer.dart';

part 'inbox_event.dart';
part 'inbox_state.dart';

// ─── BLOC ──────────────────────────────────────────────────────────────────

class InboxBloc extends Bloc<InboxEvent, InboxState> {
  final WatchIncomingTransfers _watchIncoming;
  final DownloadTransfer _downloadTransfer;
  final FirebaseAuth _firebaseAuth;
  final LocalTransferDataSource _localDs;

  StreamSubscription? _transfersSubscription;
  final Map<String, StreamSubscription> _downloadSubscriptions = {};
  final Set<String> _processedTransferIds = {};

  InboxBloc({
    required WatchIncomingTransfers watchIncomingTransfers,
    required DownloadTransfer downloadTransfer,
    required FirebaseAuth firebaseAuth,
    required LocalTransferDataSource localTransferDataSource,
  }) : _watchIncoming = watchIncomingTransfers,
       _downloadTransfer = downloadTransfer,
       _firebaseAuth = firebaseAuth,
       _localDs = localTransferDataSource,
       super(InboxInitial()) {
    on<InboxStarted>(_onStarted);
    on<TransfersUpdated>(_onTransfersUpdated);
    on<DownloadRequested>(_onDownloadRequested);
    on<DownloadFileRequested>(_onDownloadFileRequested);
    on<DownloadProgressUpdated>(_onProgressUpdated);
    on<TransferFailed>(_onTransferFailed);
    on<_DownloadCleared>(_onDownloadCleared);
  }

  void _onStarted(InboxStarted event, Emitter<InboxState> emit) {
    // Load persisted saved file IDs from Hive so ticks survive app restarts
    final persistedSavedIds = _localDs.getSavedFileIds();

    emit(InboxLoading());
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null) {
      emit(const InboxError('User not authenticated. Please log in first.'));
      return;
    }

    _transfersSubscription?.cancel();
    _transfersSubscription = _watchIncoming(uid).listen(
      (result) => result.fold(
        (failure) => add(TransferFailed('', failure.message)),
        (transfers) => add(TransfersUpdated(transfers)),
      ),
    );
    AppLogger.step('InboxBloc: watching transfers for uid=$uid');

    // Seed the in-memory set with persisted data
    if (persistedSavedIds.isNotEmpty) {
      emit(InboxLoaded(transfers: const [], savedFileIds: persistedSavedIds));
    }
  }

  void _onTransfersUpdated(TransfersUpdated event, Emitter<InboxState> emit) {
    final current = state is InboxLoaded
        ? (state as InboxLoaded)
        : const InboxLoaded(transfers: []);

    final fresh = event.transfers
        .where((t) => !_processedTransferIds.contains(t.transferId))
        .toList();

    // Merge persisted saved IDs so ticks are correct after Firestore updates
    final merged = current.savedFileIds.union(_localDs.getSavedFileIds());

    emit(current.copyWith(transfers: fresh, savedFileIds: merged));
  }

  // ── Batch download all files in a transfer ─────────────────────────────────

  void _onDownloadRequested(DownloadRequested event, Emitter<InboxState> emit) {
    if (state is! InboxLoaded) return;
    final current = state as InboxLoaded;
    final key = event.transferId;

    if (current.activeDownloads.contains(key)) return;
    AppLogger.step(
      'InboxBloc: DownloadRequested[$key] — using Pigeon saveToDownloads',
    );

    emit(current.copyWith(activeDownloads: {...current.activeDownloads, key}));

    _downloadSubscriptions[key] = _downloadTransfer(event.transferId).listen(
      (result) => result.fold(
        (failure) {
          AppLogger.error('Download failed for $key', data: failure.message);
          add(
            TransferFailed(event.transferId, failure.message, downloadKey: key),
          );
        },
        (transfer) {
          add(DownloadProgressUpdated(transfer));
          if (transfer.status == TransferStatus.complete) {
            _processedTransferIds.add(transfer.transferId);
          }
        },
      ),
      onError: (e) {
        AppLogger.error('Download stream error for $key', data: e.toString());
        add(TransferFailed(event.transferId, e.toString(), downloadKey: key));
      },
      onDone: () {
        AppLogger.success('Download stream closed for $key');
        add(_DownloadCleared(key));
      },
    );
  }

  // ── Single-file download ───────────────────────────────────────────────────

  void _onDownloadFileRequested(
    DownloadFileRequested event,
    Emitter<InboxState> emit,
  ) {
    if (state is! InboxLoaded) return;
    final current = state as InboxLoaded;
    final key = '${event.transferId}_${event.fileId}';

    if (current.activeDownloads.contains(key)) return;
    AppLogger.step(
      'InboxBloc: DownloadFileRequested[$key] — using Pigeon saveToDownloads',
    );

    emit(current.copyWith(activeDownloads: {...current.activeDownloads, key}));

    _downloadSubscriptions[key] =
        _downloadTransfer(event.transferId, event.fileId).listen(
          (result) => result.fold((failure) {
            AppLogger.error(
              'File download failed [$key]',
              data: failure.message,
            );
            add(
              TransferFailed(
                event.transferId,
                failure.message,
                downloadKey: key,
              ),
            );
          }, (transfer) => add(DownloadProgressUpdated(transfer))),
          onError: (e) {
            AppLogger.error(
              'File download stream error [$key]',
              data: e.toString(),
            );
            add(
              TransferFailed(event.transferId, e.toString(), downloadKey: key),
            );
          },
          onDone: () {
            AppLogger.success('File download stream closed [$key]');
            add(_DownloadCleared(key));
          },
        );
  }

  void _onProgressUpdated(
    DownloadProgressUpdated event,
    Emitter<InboxState> emit,
  ) {
    if (state is! InboxLoaded) return;
    final current = state as InboxLoaded;

    final updatedList = current.transfers.map((t) {
      return t.transferId == event.transfer.transferId ? event.transfer : t;
    }).toList();

    final newSavedFileIds = Set<String>.from(current.savedFileIds);
    final newSavedTransferIds = Set<String>.from(current.savedTransferIds);

    for (final f in event.transfer.files) {
      if (f.status == FileStatus.complete) newSavedFileIds.add(f.fileId);
    }
    final allSaved = event.transfer.files.every(
      (f) => newSavedFileIds.contains(f.fileId),
    );
    if (allSaved) newSavedTransferIds.add(event.transfer.transferId);

    final newActive = Set<String>.from(current.activeDownloads)
      ..removeWhere((k) {
        if (allSaved && k == event.transfer.transferId) return true;
        for (final f in event.transfer.files) {
          if (k == '${event.transfer.transferId}_${f.fileId}' &&
              f.status == FileStatus.complete)
            return true;
        }
        return false;
      });

    emit(
      current.copyWith(
        transfers: updatedList,
        activeDownloads: newActive,
        savedFileIds: newSavedFileIds,
        savedTransferIds: newSavedTransferIds,
      ),
    );
  }

  void _onDownloadCleared(_DownloadCleared event, Emitter<InboxState> emit) {
    if (state is! InboxLoaded) return;
    final current = state as InboxLoaded;
    if (!current.activeDownloads.contains(event.downloadKey)) return;
    emit(
      current.copyWith(
        activeDownloads: Set.from(current.activeDownloads)
          ..remove(event.downloadKey),
      ),
    );
  }

  void _onTransferFailed(TransferFailed event, Emitter<InboxState> emit) {
    if (state is! InboxLoaded) return;
    final current = state as InboxLoaded;

    if (event.transferId.isEmpty) {
      emit(InboxError(event.reason));
      return;
    }

    final newActive = Set<String>.from(current.activeDownloads)
      ..remove(event.transferId)
      ..remove(event.downloadKey ?? event.transferId);

    emit(
      current.copyWith(
        activeDownloads: newActive,
        errors: {...current.errors, event.transferId: event.reason},
      ),
    );
  }

  @override
  Future<void> close() {
    _transfersSubscription?.cancel();
    for (final sub in _downloadSubscriptions.values) {
      sub.cancel();
    }
    return super.close();
  }
}
