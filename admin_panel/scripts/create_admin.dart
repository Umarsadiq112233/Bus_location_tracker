import 'dart:convert';
import 'dart:io';

void main() async {
  print('=== CREATE ADMIN ROLE USER ===');
  stdout.write('Enter Admin Email: ');
  final email = stdin.readLineSync()?.trim();
  if (email == null || email.isEmpty) {
    print('Error: Email cannot be empty.');
    exit(1);
  }

  stdout.write('Enter Admin Password (min 6 chars): ');
  final password = stdin.readLineSync()?.trim();
  if (password == null || password.length < 6) {
    print('Error: Password must be at least 6 characters.');
    exit(1);
  }

  stdout.write('Enter Admin Full Name: ');
  final name = stdin.readLineSync()?.trim();
  if (name == null || name.isEmpty) {
    print('Error: Name cannot be empty.');
    exit(1);
  }

  stdout.write('Enter Admin Phone Number: ');
  final phone = stdin.readLineSync()?.trim();
  if (phone == null || phone.isEmpty) {
    print('Error: Phone cannot be empty.');
    exit(1);
  }

  print('\nCreating admin user in Firebase Auth...');
  final apiKey = 'AIzaSyBMDXCDQjKi4eYeY4cTIul5TP1WtqnYcjc';
  final projectId = 'bus-location-tracker-b309f';

  final authUrl = Uri.parse(
    'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey',
  );

  final client = HttpClient();
  try {
    final authRequest = await client.postUrl(authUrl);
    authRequest.headers.contentType = ContentType.json;
    authRequest.write(
      jsonEncode({
        'email': email,
        'password': password,
        'returnSecureToken': true,
      }),
    );

    final authResponse = await authRequest.close();
    final authBody = await authResponse.transform(utf8.decoder).join();
    final authJson = jsonDecode(authBody) as Map<String, dynamic>;

    if (authResponse.statusCode != 200) {
      final errorMsg = authJson['error']?['message'] ?? 'Unknown authentication error';
      print('Firebase Auth Error: $errorMsg');
      exit(1);
    }

    final uid = authJson['localId'] as String;
    final idToken = authJson['idToken'] as String;
    print('User created successfully in Auth (UID: $uid).');

    print('Seeding admin role into Firestore...');
    final firestoreUrl = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/users/$uid',
    );

    final firestoreRequest = await client.patchUrl(firestoreUrl);
    firestoreRequest.headers.contentType = ContentType.json;
    firestoreRequest.headers.add('Authorization', 'Bearer $idToken');

    final isoTimestamp = DateTime.now().toUtc().toIso8601String();
    firestoreRequest.write(
      jsonEncode({
        'fields': {
          'name': {'stringValue': name},
          'email': {'stringValue': email},
          'phone': {'stringValue': phone},
          'role': {'stringValue': 'admin'},
          'createdAt': {'timestampValue': isoTimestamp},
        }
      }),
    );

    final firestoreResponse = await firestoreRequest.close();
    final firestoreBody = await firestoreResponse.transform(utf8.decoder).join();

    if (firestoreResponse.statusCode == 200) {
      print('\nSUCCESS: Admin user successfully created & seeded!');
      print('Email: $email');
      print('UID: $uid');
      print('Role: admin');
    } else {
      print('Firestore Error (HTTP ${firestoreResponse.statusCode}): $firestoreBody');
      exit(1);
    }
  } catch (e) {
    print('An unexpected error occurred: $e');
  } finally {
    client.close();
  }
}
