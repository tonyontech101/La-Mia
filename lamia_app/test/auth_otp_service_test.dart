// ignore_for_file: subtype_of_sealed_class, must_be_immutable

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamia_app/features/auth/data/auth_service.dart';

class MockUser implements User {
  MockUser({this.isVerified = false, this.emailAddress = 'test@example.com'});
  bool isVerified;
  String emailAddress;

  @override
  String get uid => 'user_123';

  @override
  bool get emailVerified => isVerified;

  @override
  String? get email => emailAddress;

  @override
  Future<void> reload() async {
    isVerified = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockUserCredential implements UserCredential {
  MockUserCredential(this._user);
  final User? _user;

  @override
  User? get user => _user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockFirebaseAuth implements FirebaseAuth {
  MockFirebaseAuth(this.mockUser);
  final MockUser? mockUser;

  @override
  User? get currentUser => mockUser;

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return MockUserCredential(mockUser);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockHttpsCallable implements HttpsCallable {
  MockHttpsCallable(this.onCall);
  final Future<dynamic> Function(dynamic parameters) onCall;

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    final res = await onCall(parameters);
    return MockHttpsCallableResult<T>(res as T);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockHttpsCallableResult<T> implements HttpsCallableResult<T> {
  MockHttpsCallableResult(this.data);
  @override
  final T data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockFirebaseFunctions implements FirebaseFunctions {
  MockFirebaseFunctions({
    this.sendHandler,
    this.verifyHandler,
  });

  Future<dynamic> Function(dynamic parameters)? sendHandler;
  Future<dynamic> Function(dynamic parameters)? verifyHandler;

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) {
    if (name == 'sendEmailOtp') {
      return MockHttpsCallable((params) async {
        return sendHandler != null
            ? await sendHandler!(params)
            : <String, dynamic>{'success': true};
      });
    }
    if (name == 'verifyEmailOtp') {
      return MockHttpsCallable((params) async {
        return verifyHandler != null
            ? await verifyHandler!(params)
            : <String, dynamic>{'success': true};
      });
    }
    throw UnimplementedError('No mock for $name');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockDocumentSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  MockDocumentSnapshot(this._exists);
  final bool _exists;
  @override
  bool get exists => _exists;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockDocumentReference implements DocumentReference<Map<String, dynamic>> {
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    return MockDocumentSnapshot(true);
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockCollectionReference implements CollectionReference<Map<String, dynamic>> {
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    return MockDocumentReference();
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockFirebaseFirestore implements FirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return MockCollectionReference();
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('AuthService OTP methods', () {
    late MockUser mockUser;
    late MockFirebaseAuth mockAuth;
    late MockFirebaseFunctions mockFunctions;
    late MockFirebaseFirestore mockFirestore;
    late AuthService authService;

    setUp(() {
      mockUser = MockUser();
      mockAuth = MockFirebaseAuth(mockUser);
      mockFunctions = MockFirebaseFunctions();
      mockFirestore = MockFirebaseFirestore();
      authService = AuthService(
        auth: mockAuth,
        functions: mockFunctions,
        firestore: mockFirestore,
      );
    });

    test('sendEmailOtp passes purpose and targetEmail to callable', () async {
      dynamic capturedParams;
      mockFunctions.sendHandler = (params) async {
        capturedParams = params;
        return {'success': true, 'cooldownSeconds': 60};
      };

      await authService.sendEmailOtp(
        purpose: 'signup',
        targetEmail: 'newuser@example.com',
      );

      expect(capturedParams, isNotNull);
      expect(capturedParams['purpose'], 'signup');
      expect(capturedParams['targetEmail'], 'newuser@example.com');
    });

    test('verifyEmailOtp reloads user and returns true on success', () async {
      dynamic capturedParams;
      mockFunctions.verifyHandler = (params) async {
        capturedParams = params;
        return {'success': true, 'emailVerified': true};
      };

      expect(mockUser.emailVerified, isFalse);

      final result = await authService.verifyEmailOtp(
        code: '123456',
        purpose: 'signup',
      );

      expect(result, isTrue);
      expect(capturedParams['code'], '123456');
      expect(capturedParams['purpose'], 'signup');
      expect(mockUser.emailVerified, isTrue);
    });

    test('verifyOtpAndCreateAccount calls callable with credentials and signs in', () async {
      dynamic capturedParams;
      mockFunctions.verifyHandler = (params) async {
        capturedParams = params;
        return {'success': true, 'emailVerified': true, 'uid': 'user_123'};
      };

      final user = await authService.verifyOtpAndCreateAccount(
        code: '654321',
        email: 'test@example.com',
        password: 'Password123!',
        displayName: 'Test User',
      );

      expect(user.uid, 'user_123');
      expect(capturedParams['code'], '654321');
      expect(capturedParams['purpose'], 'signup');
      expect(capturedParams['email'], 'test@example.com');
      expect(capturedParams['password'], 'Password123!');
      expect(capturedParams['displayName'], 'Test User');
    });
  });
}
