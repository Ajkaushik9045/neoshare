import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../utils/app_logger.dart';
import '../../features/identity/data/datasources/firestore_identity_ds.dart';
import '../../features/identity/data/datasources/local_identity_ds.dart';
import '../../features/identity/data/repositories/identity_repo_impl.dart';
import '../../features/identity/domain/repositories/identity_repo.dart';
import '../../features/identity/domain/usecases/provision_identity.dart';
import '../../features/identity/presentation/bloc/identity_bloc.dart';
import '../../features/transfer/data/datasources/firestore_transfer_ds.dart';
import '../../features/transfer/data/datasources/storage_ds.dart';
import '../../features/transfer/data/repositories/transfer_repo_impl.dart';
import '../../features/transfer/domain/repositories/transfer_repo.dart';
import '../../features/transfer/domain/usecases/send_transfer.dart';
import '../../features/transfer/presentation/bloc/send_bloc.dart';

/// Global service locator for dependency registration and retrieval.
final GetIt sl = GetIt.instance;

/// Registers app dependencies.
Future<void> setupServiceLocator() async {
  AppLogger.step('Initializing Hive local storage');
  await Hive.initFlutter();
  final identityBox = await Hive.openBox<dynamic>(LocalIdentityDataSource.boxName);
  AppLogger.success('Hive initialized and identity box opened');

  sl
    ..registerLazySingleton<FirebaseAuth>(() => FirebaseAuth.instance)
    ..registerLazySingleton<FirebaseFirestore>(() => FirebaseFirestore.instance)
    ..registerLazySingleton<FirebaseStorage>(() => FirebaseStorage.instance)
    ..registerLazySingleton<LocalIdentityDataSource>(
      () => LocalIdentityDataSource(identityBox),
    )
    ..registerLazySingleton<FirestoreIdentityDataSource>(
      () => FirestoreIdentityDataSource(sl<FirebaseFirestore>()),
    )
    ..registerLazySingleton<IdentityRepo>(
      () => IdentityRepoImpl(
        identityDataSource: sl<FirestoreIdentityDataSource>(),
        localIdentityDataSource: sl<LocalIdentityDataSource>(),
        firebaseAuth: sl<FirebaseAuth>(),
      ),
    )
    ..registerLazySingleton<ProvisionIdentity>(
      () => ProvisionIdentity(sl<IdentityRepo>()),
    )
    ..registerLazySingleton<StorageDataSource>(
      () => StorageDataSource(sl<FirebaseStorage>()),
    )
    ..registerLazySingleton<FirestoreTransferDataSource>(
      () => FirestoreTransferDataSource(sl<FirebaseFirestore>()),
    )
    ..registerLazySingleton<TransferRepo>(
      () => TransferRepoImpl(
        storageDataSource: sl<StorageDataSource>(),
        firestoreTransferDataSource: sl<FirestoreTransferDataSource>(),
        firestore: sl<FirebaseFirestore>(),
      ),
    )
    ..registerLazySingleton<SendTransfer>(
      () => SendTransfer(sl<TransferRepo>()),
    )
    ..registerFactory<IdentityBloc>(
      () => IdentityBloc(sl<ProvisionIdentity>()),
    )
    ..registerFactory<SendBloc>(
      () => SendBloc(sl<TransferRepo>()),
    );

  AppLogger.success('Dependency graph registration completed');
}
