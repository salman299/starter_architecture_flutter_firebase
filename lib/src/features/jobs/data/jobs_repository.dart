import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:starter_architecture_flutter_firebase/src/features/authentication/data/firebase_auth_repository.dart';
import 'package:starter_architecture_flutter_firebase/src/features/authentication/domain/app_user.dart';
import 'package:starter_architecture_flutter_firebase/src/features/entries/data/entries_repository.dart';
import 'package:starter_architecture_flutter_firebase/src/features/entries/domain/entry.dart';
import 'package:starter_architecture_flutter_firebase/src/features/jobs/domain/job.dart';

class JobsRepository {
  const JobsRepository(this._firestore);
  final FirebaseFirestore _firestore;

  static String jobPath(String uid, String jobId) => 'users/$uid/jobs/$jobId';
  static String jobsPath(String uid) => 'users/$uid/jobs';
  static String entriesPath(String uid) => EntriesRepository.entriesPath(uid);

  // create
  Future<void> addJob(
          {required UserID uid,
          required String name,
          required int ratePerHour}) =>
      _firestore.collection(jobsPath(uid)).add({
        'name': name,
        'ratePerHour': ratePerHour,
      });

  // update
  Future<void> updateJob({required UserID uid, required Job job}) =>
      _firestore.doc(jobPath(uid, job.id)).update(job.toMap());

  // delete
  Future<void> deleteJob({required UserID uid, required JobID jobId}) async {
    // delete where entry.jobId == job.jobId
    final entriesRef = _firestore.collection(entriesPath(uid));
    final entries = await entriesRef.get();
    for (final snapshot in entries.docs) {
      final entry = Entry.fromMap(snapshot.data(), snapshot.id);
      if (entry.jobId == jobId) {
        await snapshot.reference.delete();
      }
    }
    // delete job
    final jobRef = _firestore.doc(jobPath(uid, jobId));
    await jobRef.delete();
  }

  // read
  Stream<Job> watchJob({required UserID uid, required JobID jobId}) =>
      _firestore
          .doc(jobPath(uid, jobId))
          .withConverter<Job>(
            fromFirestore: (snapshot, _) =>
                Job.fromMap(snapshot.data()!, snapshot.id),
            toFirestore: (job, _) => job.toMap(),
          )
          .snapshots()
          .map((snapshot) => snapshot.data()!);

  Stream<List<Job>> watchJobs({required UserID uid}) => queryJobs(uid: uid)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());

  Query<Job> queryJobs({required UserID uid}) =>
      _firestore.collection(jobsPath(uid)).withConverter(
            fromFirestore: (snapshot, _) =>
                Job.fromMap(snapshot.data()!, snapshot.id),
            toFirestore: (job, _) => job.toMap(),
          );

  Future<List<Job>> fetchJobs({required UserID uid}) async {
    final jobs = await queryJobs(uid: uid).get();
    return jobs.docs.map((doc) => doc.data()).toList();
  }
}

final jobsRepositoryProvider = Provider<JobsRepository>((ref) {
  return JobsRepository(FirebaseFirestore.instance);
});

final jobsQueryProvider = Provider<Query<Job>>((ref) {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) {
    throw AssertionError('User can\'t be null');
  }
  final repository = ref.watch(jobsRepositoryProvider);
  return repository.queryJobs(uid: user.uid);
});

final jobStreamProvider =
    StreamProvider.autoDispose.family<Job, JobID>((ref, jobId) {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) {
    throw AssertionError('User can\'t be null');
  }
  final repository = ref.watch(jobsRepositoryProvider);
  return repository.watchJob(uid: user.uid, jobId: jobId);
});
