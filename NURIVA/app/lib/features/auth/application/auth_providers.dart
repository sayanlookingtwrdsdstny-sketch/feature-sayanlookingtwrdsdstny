import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nuriva/features/auth/data/firebase_auth_repository.dart';
import 'package:nuriva/features/auth/data/firestore_profile_repository.dart';
import 'package:nuriva/features/auth/domain/account_service.dart';
import 'package:nuriva/features/auth/domain/auth_models.dart';
import 'package:nuriva/features/auth/domain/auth_repositories.dart';

/// Authentication backend. Firebase in the app; overridden with an in-memory
/// fake in tests, so no test needs a live Firebase project.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => FirebaseAuthRepository(FirebaseAuth.instance),
);

/// Profile persistence. Firestore in the app; overridden in tests.
final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => FirestoreProfileRepository(FirebaseFirestore.instance),
);

final accountServiceProvider = Provider<AccountService>(
  (ref) => AccountService(
    auth: ref.watch(authRepositoryProvider),
    profiles: ref.watch(profileRepositoryProvider),
  ),
);

/// The signed-in account, or `null`.
final authUserProvider = StreamProvider<AuthUser?>(
  (ref) => ref.watch(authRepositoryProvider).userChanges(),
);

final profileProvider = StreamProvider.family<UserProfile?, String>(
  (ref, uid) => ref.watch(profileRepositoryProvider).watchProfile(uid),
);

/// Where the user is in the sign-in lifecycle (ARCHITECTURE §5).
///
/// The router listens to this, so signing out — or a session expiring —
/// redirects immediately without any screen having to handle it.
final sessionProvider = Provider<AuthSession>((ref) {
  final auth = ref.watch(authUserProvider);

  return auth.when(
    loading: () => const SessionLoading(),
    // An auth stream error is not proof of a session; treat as signed out.
    error: (_, _) => const SignedOut(),
    data: (user) {
      if (user == null) return const SignedOut();
      if (!user.emailVerified) return AwaitingVerification(user);

      final profile = ref.watch(profileProvider(user.uid));
      return profile.when(
        loading: () => const SessionLoading(),
        error: (_, _) => SessionUnavailable(user),
        data: (p) => p == null ? NeedsProfile(user) : SignedIn(user, p),
      );
    },
  );
});
