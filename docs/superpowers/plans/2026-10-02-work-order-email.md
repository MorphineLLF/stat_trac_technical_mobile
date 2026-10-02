# Work Order Email Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On a synced captured work order, the technician can open the job card PDF and email it to the client — the same two buttons and email box a certificate has.

**Architecture:** The certificate's document result types and email box move to `lib/core/documents/` under neutral names; the certificate screen points at them unchanged in behaviour. A new `WorkOrderDocumentClient` (copy of `CertDocumentClient` in shape) calls the Go work order routes with the device token. The work order detail screen gets an app bar actions widget.

**Tech Stack:** Flutter, Riverpod 3 (`@riverpod` codegen), Dio, `open_file`, `path_provider`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-10-02-work-order-email-design.md` · Go side: `docs/go-requirements-work-order-email.md`

## Global Constraints

- Routes: `GET /{company}/work-order/{id}/print.pdf`, `GET /{company}/work-order/{id}/email`, `POST /{company}/work-order/{id}/email`.
- Device token as `Authorization: Bearer`; no interceptor; `validateStatus: (_) => true`.
- Every outcome is a result, never an exception (no signal included).
- `lib/core/` imports nothing from `lib/features/`. Features never import each other.
- Certificate behaviour does not change.
- Widget tests pump the real `appTheme`.
- Every `FilledButton` is full width — never inside a `Row`.
- Phone layout only (384 dp wide reference).
- All work lands on `master`; no branches.

## Review Focus

1. **Server without the Go work yet** (today's `demo`) — the PDF route answers 403 JSON `{"error": "..."}`; the technician sees the sentence, not braces, and nothing crashes. Pinned in Task 3.
2. **No signal** — PDF and email both say "Cannot reach the server. Try again when you have signal." Pinned in Task 3.
3. **A work order the office changed after it was cached** — unlike an issued certificate, a work order can change. So: fetch fresh when the server answers; fall back to the cached copy only when the server is unreachable. Pinned in Task 4 (`pdfToOpen`).
4. **Queued job (no `RepairTrackID` yet)** — both buttons disabled with "Sync first". Pinned in Task 4.
5. **Server returns the work order id as `work_order`, not `certificate`** — the sent result reads either. Pinned in Task 1.

---

### Task 1: Move the document result types to core

**Files:**
- Move: `lib/features/certification/data/cert_document_result.dart` → `lib/core/documents/document_result.dart`
- Move: `test/features/certification/cert_document_result_test.dart` → `test/core/documents/document_result_test.dart`
- Modify: `lib/features/certification/data/cert_document_client.dart`
- Modify: `lib/features/certification/presentation/screens/certificate_detail_screen.dart`

**Interfaces:**
- Produces (in `lib/core/documents/document_result.dart`): `DocPdfResult` (`DocPdfBytes(Uint8List bytes)`, `DocPdfNotReady(String message)`, `DocPdfRefused(int status, String message)`, `DocPdfUnavailable(int status, String message)`), `DocPdfResult docPdfResultFromResponse(int status, String body)`, `DocEmailResult` (`DocEmailSent({int? id, String? number, List<String> to})`, `DocEmailRefused({reason, message, field})`, `DocEmailUnavailable(String reason, String message)`), `DocEmailResult docEmailResultFromResponse(int status, Map<String, Object?> body)`, `DocEmailDefaults`, `DocEmailDefaults? docEmailDefaultsFromResponse(int, Map<String, Object?>)`, `({String? cc, String? body}) docEmailFields({required bool defaultsShown, required String cc, required String body})`.

- [ ] **Step 1: Move the files**

```bash
mkdir -p lib/core/documents test/core/documents
git mv lib/features/certification/data/cert_document_result.dart lib/core/documents/document_result.dart
git mv test/features/certification/cert_document_result_test.dart test/core/documents/document_result_test.dart
```

- [ ] **Step 2: Rename the identifiers everywhere they are used**

```bash
sed -i -e 's/CertPdf/DocPdf/g; s/CertEmail/DocEmail/g; s/certPdfResultFromResponse/docPdfResultFromResponse/g; s/certEmailResultFromResponse/docEmailResultFromResponse/g; s/certEmailDefaultsFromResponse/docEmailDefaultsFromResponse/g; s/certEmailFields/docEmailFields/g' \
  lib/core/documents/document_result.dart \
  test/core/documents/document_result_test.dart \
  lib/features/certification/data/cert_document_client.dart \
  lib/features/certification/presentation/screens/certificate_detail_screen.dart
```

Then fix the imports:
- `cert_document_client.dart`: `import 'cert_document_result.dart';` → `import '../../../core/documents/document_result.dart';`
- `certificate_detail_screen.dart`: `import '../../data/cert_document_result.dart';` → `import '../../../../core/documents/document_result.dart';`
- the test: `package:stat_trac_technical/features/certification/data/cert_document_result.dart` → `package:stat_trac_technical/core/documents/document_result.dart`

- [ ] **Step 3: Write the failing test** — append inside `group('the email', ...)` in `test/core/documents/document_result_test.dart`:

```dart
    // The work order route names its id `work_order`, the certificate route
    // `certificate`. One result type reads both.
    test('a work order send reads its id', () {
      final r = docEmailResultFromResponse(200, const {
        'sent': true,
        'work_order': 7144,
        'to': ['sister@hospital.example'],
      });

      expect((r as DocEmailSent).id, 7144);
    });

    test('a certificate send reads its id', () {
      final r = docEmailResultFromResponse(200, const {
        'sent': true,
        'certificate': 8475,
        'number': '8475',
        'to': ['a@b.example'],
      });

      expect((r as DocEmailSent).id, 8475);
    });
```

- [ ] **Step 4: Run it to see it fail**

Run: `flutter test test/core/documents/document_result_test.dart`
Expected: FAIL — `The getter 'id' isn't defined for the type 'DocEmailSent'`.

- [ ] **Step 5: Make it pass** — in `lib/core/documents/document_result.dart`:

Replace the file's opening doc comment (lines 4–8) with:

```dart
/// What the Go application answers when asked for a document — a certificate
/// or a work order sheet. The two routes answer in the same shapes.
///
/// Written for that server and nothing else. These routes return the bytes,
/// and their refusals arrive in two shapes rather than one.
```

Replace `DocEmailSent`:

```dart
class DocEmailSent extends DocEmailResult {
  const DocEmailSent({this.id, this.number, this.to = const []});

  /// The certificate's or the work order's id, whichever route answered.
  final int? id;
  final String? number;
  final List<String> to;

  @override
  bool get isRetryable => false;
}
```

In `docEmailResultFromResponse`, change the fallback message and the sent branch:

```dart
  final message =
      (body['error'] as String?) ?? 'The document could not be emailed.';

  if (status == 200) {
    return DocEmailSent(
      id: ((body['certificate'] ?? body['work_order']) as num?)?.toInt(),
      number: body['number'] as String?,
      to: [for (final a in (body['to'] as List?) ?? const []) a as String],
    );
  }
```

- [ ] **Step 6: Run the tests and analyze**

Run: `flutter test test/core/documents/document_result_test.dart` → all PASS
Run: `flutter analyze` → No issues found

- [ ] **Step 7: Commit**

```bash
git add -A lib/core/documents test/core/documents lib/features/certification test/features/certification
git commit -m "refactor(documents): certificate document results move to core, neutral names"
```

---

### Task 2: Move the email box to core

**Files:**
- Create: `lib/core/documents/email_document_dialog.dart`
- Modify: `lib/features/certification/presentation/screens/certificate_detail_screen.dart` (delete `_EmailDialog` / `_EmailDialogState`, lines ~433–611; use the new widget)
- Test: `test/core/documents/email_document_dialog_test.dart`

**Interfaces:**
- Consumes: `DocEmailDefaults`, `docEmailFields` (Task 1).
- Produces: `EmailDocumentDialog({required String title, required String sentLabel, required Future<DocEmailDefaults?> Function() loadDefaults, required Future<void> Function(String to, String? cc, String? body) onSend})`. `onSend` throws `StateError(message)` to show a refusal inside the box.

- [ ] **Step 1: Write the failing test** — `test/core/documents/email_document_dialog_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/core/documents/document_result.dart';
import 'package:stat_trac_technical/core/documents/email_document_dialog.dart';
import 'package:stat_trac_technical/core/theme/app_theme.dart';

Future<void> _open(
  WidgetTester t, {
  DocEmailDefaults? defaults,
  Future<void> Function(String, String?, String?)? onSend,
}) async {
  await t.pumpWidget(
    MaterialApp(
      theme: appTheme,
      home: Builder(
        builder: (c) => Scaffold(
          body: TextButton(
            onPressed: () => showDialog<void>(
              context: c,
              builder: (_) => EmailDocumentDialog(
                title: 'Email Work Order',
                sentLabel: 'Work order',
                loadDefaults: () async => defaults,
                onSend: onSend ?? (_, _, _) async {},
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
}

FilledButton _send(WidgetTester t) =>
    t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Send'));

void main() {
  testWidgets('shows its title; Send waits for an address', (t) async {
    await _open(t);
    expect(find.text('Email Work Order'), findsOneWidget);
    expect(_send(t).onPressed, isNull);

    await t.enterText(find.byType(TextField).first, 'sister@hospital.example');
    await t.pump();
    expect(_send(t).onPressed, isNotNull);
  });

  testWidgets("opens with the sender's CC and sign-off", (t) async {
    await _open(
      t,
      defaults: const DocEmailDefaults(cc: 'office@co.example', signature: 'Athi'),
    );
    expect(find.text('office@co.example'), findsOneWidget);
    expect(find.textContaining('Athi'), findsOneWidget);
  });

  testWidgets('a refusal stays in the box', (t) async {
    await _open(
      t,
      onSend: (_, _, _) async => throw StateError('an address is needed'),
    );
    await t.enterText(find.byType(TextField).first, 'a@b.example');
    await t.pump();
    await t.tap(find.text('Send'));
    await t.pumpAndSettle();
    expect(find.text('Email Work Order'), findsOneWidget);
    expect(find.textContaining('an address is needed'), findsOneWidget);
  });

  testWidgets('a send closes the box and names what went', (t) async {
    String? sentTo;
    await _open(t, onSend: (to, _, _) async => sentTo = to);
    await t.enterText(find.byType(TextField).first, ' a@b.example ');
    await t.pump();
    await t.tap(find.text('Send'));
    await t.pumpAndSettle();
    expect(sentTo, 'a@b.example');
    expect(find.text('Email Work Order'), findsNothing);
    expect(find.text('Work order emailed to a@b.example'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test test/core/documents/email_document_dialog_test.dart`
Expected: FAIL — `email_document_dialog.dart` does not exist.

- [ ] **Step 3: Create `lib/core/documents/email_document_dialog.dart`**

Cut `_EmailDialog` and `_EmailDialogState` out of `certificate_detail_screen.dart` and paste them here, then change exactly these things:

1. Imports at the top of the new file:

```dart
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'document_result.dart';
```

2. Class names `_EmailDialog` → `EmailDocumentDialog`, `_EmailDialogState` → `_EmailDocumentDialogState`; `createState` returns `_EmailDocumentDialogState()`.

3. Replace the constructor and fields (drop `serverId` — the box never used it):

```dart
/// The box a document is emailed from — a certificate or a work order.
///
/// The recipient is typed: no contact table and no email column reach this
/// device. The CC and message open with the technician's own CC and sign-off,
/// asked of the server as the box opens — they live on the Admin row, which
/// does not sync.
class EmailDocumentDialog extends StatefulWidget {
  const EmailDocumentDialog({
    super.key,
    required this.title,
    required this.sentLabel,
    required this.loadDefaults,
    required this.onSend,
  });

  /// "Email Certificate" / "Email Work Order".
  final String title;

  /// "Certificate" / "Work order" — the start of the sent message.
  final String sentLabel;
  final Future<DocEmailDefaults?> Function() loadDefaults;

  /// [cc] and [body] null means "left out" — the server fills them in.
  /// Throws `StateError(message)` to show a refusal inside the box.
  final Future<void> Function(String to, String? cc, String? body) onSend;

  @override
  State<EmailDocumentDialog> createState() => _EmailDocumentDialogState();
}
```

4. In the success snackbar: `'Certificate emailed to ${...}'` → `'${widget.sentLabel} emailed to ${_controller.text.trim()}'`.

5. `title: const Text('Email Certificate')` → `title: Text(widget.title)`.

6. The error text: `_error = e.toString()` shows `Bad state: ...`. Change the catch to:

```dart
    } on StateError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
```

- [ ] **Step 4: Point the certificate screen at it** — in `certificate_detail_screen.dart`:

Add `import '../../../../core/documents/email_document_dialog.dart';` and in `_showEmailDialog` replace

```dart
      builder: (_) => _EmailDialog(
        serverId: serverId,
```

with

```dart
      builder: (_) => EmailDocumentDialog(
        title: 'Email Certificate',
        sentLabel: 'Certificate',
```

Remove the `// ── Email dialog ──` section header left behind. Remove any import the screen no longer uses (`flutter analyze` names them).

- [ ] **Step 5: Run tests and analyze**

Run: `flutter test test/core/documents/ test/features/certification/` → all PASS
Run: `flutter analyze` → No issues found

- [ ] **Step 6: Commit**

```bash
git add lib/core/documents/email_document_dialog.dart test/core/documents/email_document_dialog_test.dart lib/features/certification/presentation/screens/certificate_detail_screen.dart
git commit -m "refactor(documents): the email box moves to core, titled by its caller"
```

---

### Task 3: WorkOrderDocumentClient

**Files:**
- Create: `lib/features/work_orders/data/work_order_document_client.dart`
- Test: `test/features/work_orders/work_order_document_client_test.dart`

**Interfaces:**
- Consumes: Task 1 types.
- Produces: `WorkOrderDocumentClient(Dio dio)` with
  - `Future<DocPdfResult> fetchPdf({required String company, required String deviceToken, required int trackId})`
  - `Future<DocEmailDefaults?> fetchEmailDefaults({required String company, required String deviceToken, required int trackId})`
  - `Future<DocEmailResult> email({required String company, required String deviceToken, required int trackId, required String to, String? cc, String? body})`

- [ ] **Step 1: Write the failing test** — `test/features/work_orders/work_order_document_client_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/core/documents/document_result.dart';
import 'package:stat_trac_technical/features/work_orders/data/work_order_document_client.dart';

/// Answers every request with one canned response, and remembers the request.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, this.body, {this.type = 'application/json', this.fail});
  final int status;
  final List<int> body;
  final String type;
  final DioExceptionType? fail;
  RequestOptions? seen;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    seen = options;
    if (fail != null) throw DioException(requestOptions: options, type: fail!);
    return ResponseBody.fromBytes(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [type],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

(WorkOrderDocumentClient, _Adapter) _client(_Adapter a) {
  final dio = Dio(BaseOptions(baseUrl: 'http://server'))..httpClientAdapter = a;
  return (WorkOrderDocumentClient(dio), a);
}

List<int> _json(Object o) => utf8.encode(jsonEncode(o));

void main() {
  group('the PDF', () {
    test('asks the work order route with the device token', () async {
      final (c, a) = _client(_Adapter(200, [1, 2, 3], type: 'application/pdf'));
      final r = await c.fetchPdf(company: 'demo', deviceToken: 't', trackId: 7144);

      expect((r as DocPdfBytes).bytes, [1, 2, 3]);
      expect(a.seen!.path, '/demo/work-order/7144/print.pdf');
      expect(a.seen!.headers['Authorization'], 'Bearer t');
    });

    // Today's demo server: the path is not on the handset list yet.
    test('a server without the work refuses in a sentence', () async {
      final (c, _) = _client(
        _Adapter(403, _json({'error': 'not available to the mobile app'})),
      );
      final r = await c.fetchPdf(company: 'demo', deviceToken: 't', trackId: 1);

      expect((r as DocPdfRefused).message, 'not available to the mobile app');
    });

    test('no signal is unavailable, said plainly', () async {
      final (c, _) = _client(
        _Adapter(0, const [], fail: DioExceptionType.connectionError),
      );
      final r = await c.fetchPdf(company: 'demo', deviceToken: 't', trackId: 1);

      expect(r, isA<DocPdfUnavailable>());
      expect((r as DocPdfUnavailable).message, contains('signal'));
    });
  });

  group('the email', () {
    test('sends only what it was given, to the work order route', () async {
      final (c, a) = _client(
        _Adapter(200, _json({'sent': true, 'work_order': 7144, 'to': ['a@b.example']})),
      );
      final r = await c.email(
        company: 'demo',
        deviceToken: 't',
        trackId: 7144,
        to: ' a@b.example ',
      );

      expect((r as DocEmailSent).id, 7144);
      expect(a.seen!.path, '/demo/work-order/7144/email');
      expect(a.seen!.method, 'POST');
      expect(a.seen!.data, {'to': 'a@b.example'});
    });

    test('a refusal carries its field', () async {
      final (c, _) = _client(
        _Adapter(422, _json({'reason': 'bad_address', 'error': 'not right', 'field': 'cc'})),
      );
      final r = await c.email(company: 'demo', deviceToken: 't', trackId: 1, to: 'x@y.z');

      expect((r as DocEmailRefused).field, 'cc');
    });

    test('no signal is unavailable', () async {
      final (c, _) = _client(
        _Adapter(0, const [], fail: DioExceptionType.connectionError),
      );
      final r = await c.email(company: 'demo', deviceToken: 't', trackId: 1, to: 'x@y.z');

      expect(r, isA<DocEmailUnavailable>());
    });

    test("the box's defaults", () async {
      final (c, a) = _client(
        _Adapter(200, _json({'cc': 'o@co.example', 'reply_to': 'me@co.example', 'signature': 'Athi'})),
      );
      final d = await c.fetchEmailDefaults(company: 'demo', deviceToken: 't', trackId: 7144);

      expect(d!.cc, 'o@co.example');
      expect(a.seen!.method, 'GET');
      expect(a.seen!.path, '/demo/work-order/7144/email');
    });
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test test/features/work_orders/work_order_document_client_test.dart`
Expected: FAIL — `work_order_document_client.dart` does not exist.

- [ ] **Step 3: Create `lib/features/work_orders/data/work_order_document_client.dart`**

```dart
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/documents/document_result.dart';

/// The work order sheet: fetching the PDF, and emailing it to the client.
///
/// The same shape as the certificate's client, against the work order routes,
/// with the ninety-day device token as a Bearer:
///
///   GET  /{company}/work-order/{id}/print.pdf
///   GET  /{company}/work-order/{id}/email   what the email box opens with
///   POST /{company}/work-order/{id}/email
///
/// **Every answer comes back as a result, never as an exception** — a refusal
/// is the server answering clearly, and no signal is ordinary here.
class WorkOrderDocumentClient {
  WorkOrderDocumentClient(this._dio);

  final Dio _dio;

  Options _bearer(String token, {ResponseType? type, String? contentType}) =>
      Options(
        headers: {'Authorization': 'Bearer $token'},
        responseType: type,
        contentType: contentType,
        validateStatus: (_) => true,
      );

  /// The rendered work order sheet.
  Future<DocPdfResult> fetchPdf({
    required String company,
    required String deviceToken,
    required int trackId,
  }) async {
    try {
      final response = await _dio.get<List<int>>(
        '/$company/work-order/$trackId/print.pdf',
        options: _bearer(deviceToken, type: ResponseType.bytes),
      );
      final status = response.statusCode ?? 0;
      final body = response.data ?? const <int>[];
      if (status == 200) return DocPdfBytes(Uint8List.fromList(body));
      return docPdfResultFromResponse(status, String.fromCharCodes(body));
    } on DioException catch (e) {
      return DocPdfUnavailable(0, _transportMessage(e));
    }
  }

  /// The technician's own CC, reply address and sign-off. Null when the server
  /// could not say — the box then opens empty and the server signs the mail.
  Future<DocEmailDefaults?> fetchEmailDefaults({
    required String company,
    required String deviceToken,
    required int trackId,
  }) async {
    try {
      final response = await _dio.get<Map<String, Object?>>(
        '/$company/work-order/$trackId/email',
        options: _bearer(deviceToken),
      );
      return docEmailDefaultsFromResponse(
        response.statusCode ?? 0,
        response.data ?? const {},
      );
    } on DioException {
      return null;
    }
  }

  /// Emails the work order sheet. [cc] and [body] left out (null) are filled
  /// by the server from the Admin row; sent as `''` they stay empty. See
  /// [docEmailFields].
  Future<DocEmailResult> email({
    required String company,
    required String deviceToken,
    required int trackId,
    required String to,
    String? cc,
    String? body,
  }) async {
    try {
      final response = await _dio.post<Map<String, Object?>>(
        '/$company/work-order/$trackId/email',
        data: {'to': to.trim(), 'cc': ?cc?.trim(), 'body': ?body},
        options: _bearer(deviceToken, contentType: Headers.jsonContentType),
      );
      return docEmailResultFromResponse(
        response.statusCode ?? 0,
        response.data ?? const {},
      );
    } on DioException catch (e) {
      return DocEmailUnavailable('unavailable', _transportMessage(e));
    }
  }

  static String _transportMessage(DioException e) => switch (e.type) {
    DioExceptionType.connectionError || DioExceptionType.unknown =>
      'Cannot reach the server. Try again when you have signal.',
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => 'The server timed out. Try again.',
    _ => 'Could not reach the work order. Try again.',
  };
}
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/work_orders/work_order_document_client_test.dart` → all PASS
Run: `flutter analyze` → No issues found

- [ ] **Step 5: Commit**

```bash
git add lib/features/work_orders/data/work_order_document_client.dart test/features/work_orders/work_order_document_client_test.dart
git commit -m "feat(work-orders): client for the job card PDF and email"
```

---

### Task 4: View PDF and Email on the work order detail screen

**Files:**
- Create: `lib/features/work_orders/presentation/providers/work_order_document_providers.dart` (+ generated `.g.dart`)
- Create: `lib/features/work_orders/presentation/widgets/work_order_document_actions.dart`
- Modify: `lib/features/work_orders/presentation/screens/work_order_detail_screen.dart` (AppBar `actions`)
- Test: `test/features/work_orders/work_order_document_actions_test.dart`

**Interfaces:**
- Consumes: `WorkOrderDocumentClient` (Task 3), `EmailDocumentDialog` (Task 2), Task 1 types.
- Produces: `workOrderDocumentClientProvider`, `workOrderDocumentCredentialsProvider` (`Future<({String company, String token})?>`), `WorkOrderDocumentActions({int? trackId})`, and the pure `PdfChoice pdfToOpen({required DocPdfResult fetched, required bool cached})`.

- [ ] **Step 1: Write the failing test** — `test/features/work_orders/work_order_document_actions_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stat_trac_technical/core/documents/document_result.dart';
import 'package:stat_trac_technical/core/theme/app_theme.dart';
import 'package:stat_trac_technical/features/work_orders/presentation/providers/work_order_document_providers.dart';
import 'package:stat_trac_technical/features/work_orders/presentation/widgets/work_order_document_actions.dart';

Future<void> _pump(WidgetTester t, {int? trackId}) async {
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        // Signed out: the box opens with no defaults, nothing is fetched.
        workOrderDocumentCredentialsProvider.overrideWith((ref) async => null),
      ],
      child: MaterialApp(
        theme: appTheme,
        home: Scaffold(
          appBar: AppBar(actions: [WorkOrderDocumentActions(trackId: trackId)]),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

IconButton _button(WidgetTester t, IconData icon) =>
    t.widget<IconButton>(find.widgetWithIcon(IconButton, icon));

void main() {
  testWidgets('a queued job: both disabled, says Sync first', (t) async {
    await _pump(t);
    expect(_button(t, Icons.picture_as_pdf_outlined).onPressed, isNull);
    expect(_button(t, Icons.email_outlined).onPressed, isNull);
    expect(find.byTooltip('Sync first'), findsNWidgets(2));
  });

  testWidgets('a synced job: both enabled; Email opens the box', (t) async {
    await _pump(t, trackId: 7144);
    expect(_button(t, Icons.picture_as_pdf_outlined).onPressed, isNotNull);
    expect(_button(t, Icons.email_outlined).onPressed, isNotNull);

    await t.tap(find.byIcon(Icons.email_outlined));
    await t.pumpAndSettle();
    expect(find.text('Email Work Order'), findsOneWidget);
  });

  group('which PDF opens', () {
    final bytes = DocPdfBytes(Uint8List.fromList([1]));
    const offline = DocPdfUnavailable(0, 'Cannot reach the server.');

    // A work order can change after it was printed; an issued certificate
    // cannot. So a fresh copy always wins over the cache.
    test('fresh bytes are saved and opened, cache or not', () {
      expect(pdfToOpen(fetched: bytes, cached: true), PdfChoice.saveAndOpen);
      expect(pdfToOpen(fetched: bytes, cached: false), PdfChoice.saveAndOpen);
    });

    test('no signal opens the cached copy when there is one', () {
      expect(pdfToOpen(fetched: offline, cached: true), PdfChoice.openCached);
      expect(pdfToOpen(fetched: offline, cached: false), PdfChoice.say);
    });

    // A refusal is the server's answer about this work order now; an old copy
    // would contradict it.
    test('a refusal is said, never covered by the cache', () {
      expect(
        pdfToOpen(fetched: const DocPdfRefused(404, 'no'), cached: true),
        PdfChoice.say,
      );
    });
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test test/features/work_orders/work_order_document_actions_test.dart`
Expected: FAIL — the provider and widget files do not exist.

- [ ] **Step 3: Create `lib/features/work_orders/presentation/providers/work_order_document_providers.dart`**

```dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/config/app_config.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/work_order_document_client.dart';

part 'work_order_document_providers.g.dart';

/// No interceptor: these routes take the device token as a Bearer, and a
/// cookie is turned away by the CSRF guard — as for the certificate client.
@riverpod
WorkOrderDocumentClient workOrderDocumentClient(Ref ref) {
  return WorkOrderDocumentClient(
    Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: AppConfig.connectTimeout,
        // A rendered sheet is headless Chrome plus the download.
        receiveTimeout: const Duration(seconds: 60),
      ),
    ),
  );
}

/// The company and device token these routes need, or null when signed out.
@riverpod
Future<({String company, String token})?> workOrderDocumentCredentials(
  Ref ref,
) async {
  final local = ref.watch(authLocalDataSourceProvider);
  final company = await local.readDbName();
  final token = (await local.readDeviceToken())?.token;
  if (company == null || token == null || company.isEmpty || token.isEmpty) {
    return null;
  }
  return (company: company, token: token);
}
```

Run: `dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 4: Create `lib/features/work_orders/presentation/widgets/work_order_document_actions.dart`**

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/documents/document_result.dart';
import '../../../../core/documents/email_document_dialog.dart';
import '../providers/work_order_document_providers.dart';

enum PdfChoice { saveAndOpen, openCached, say }

/// What to do with the server's answer for a work order sheet.
///
/// **Unlike an issued certificate, a work order can change after it was
/// printed** — the office adds parts, closes it. So a fresh copy always wins,
/// and the cached one is only for when the server cannot be reached at all.
/// A refusal is the server's answer now and is never covered by an old copy.
PdfChoice pdfToOpen({required DocPdfResult fetched, required bool cached}) =>
    switch (fetched) {
      DocPdfBytes() => PdfChoice.saveAndOpen,
      DocPdfUnavailable() when cached => PdfChoice.openCached,
      _ => PdfChoice.say,
    };

/// View PDF and Email, for the app bar of a work order.
///
/// A job still in the queue has no `RepairTrackID`, so there is nothing on the
/// server to render — both are disabled and say so.
class WorkOrderDocumentActions extends ConsumerStatefulWidget {
  const WorkOrderDocumentActions({super.key, this.trackId});

  final int? trackId;

  @override
  ConsumerState<WorkOrderDocumentActions> createState() =>
      _WorkOrderDocumentActionsState();
}

class _WorkOrderDocumentActionsState
    extends ConsumerState<WorkOrderDocumentActions> {
  bool _loadingPdf = false;

  Future<void> _viewPdf(int trackId) async {
    setState(() => _loadingPdf = true);
    try {
      final cacheDir = await getApplicationCacheDirectory();
      final dir = Directory('${cacheDir.path}/work_orders');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final file = File('${dir.path}/wo_$trackId.pdf');

      final credentials = await ref.read(
        workOrderDocumentCredentialsProvider.future,
      );
      final DocPdfResult fetched = credentials == null
          ? const DocPdfRefused(401, 'Sign in again to open this work order.')
          : await ref
                .read(workOrderDocumentClientProvider)
                .fetchPdf(
                  company: credentials.company,
                  deviceToken: credentials.token,
                  trackId: trackId,
                );

      switch (pdfToOpen(fetched: fetched, cached: file.existsSync())) {
        case PdfChoice.saveAndOpen:
          await file.writeAsBytes((fetched as DocPdfBytes).bytes);
        case PdfChoice.openCached:
          break;
        case PdfChoice.say:
          _say(switch (fetched) {
            DocPdfNotReady() =>
              'This work order has not reached the server yet — it needs a '
                  'moment of signal first.',
            DocPdfRefused(:final message) => message,
            DocPdfUnavailable(:final message) => message,
            DocPdfBytes() => '',
          }, isError: fetched is DocPdfRefused);
          return;
      }

      final opened = await OpenFile.open(file.path);
      if (opened.type != ResultType.done) {
        _say('Could not open PDF: ${opened.message}', isError: true);
      }
    } finally {
      if (mounted) setState(() => _loadingPdf = false);
    }
  }

  void _say(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : const Color(0xFFFFB300),
      ),
    );
  }

  Future<void> _email(int trackId) async {
    await showDialog<void>(
      context: context,
      builder: (_) => EmailDocumentDialog(
        title: 'Email Work Order',
        sentLabel: 'Work order',
        loadDefaults: () async {
          final c = await ref.read(workOrderDocumentCredentialsProvider.future);
          if (c == null) return null;
          return ref
              .read(workOrderDocumentClientProvider)
              .fetchEmailDefaults(
                company: c.company,
                deviceToken: c.token,
                trackId: trackId,
              );
        },
        onSend: (to, cc, body) async {
          final c = await ref.read(workOrderDocumentCredentialsProvider.future);
          if (c == null) {
            throw StateError('Sign in again to email this work order.');
          }
          final result = await ref
              .read(workOrderDocumentClientProvider)
              .email(
                company: c.company,
                deviceToken: c.token,
                trackId: trackId,
                to: to,
                cc: cc,
                body: body,
              );
          switch (result) {
            case DocEmailSent():
              return;
            case DocEmailRefused(:final message):
              throw StateError(message);
            case DocEmailUnavailable(:final message):
              throw StateError(message);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.trackId;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: id == null ? 'Sync first' : 'View PDF',
          child: IconButton(
            icon: _loadingPdf
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
            onPressed: id != null && !_loadingPdf ? () => _viewPdf(id) : null,
          ),
        ),
        Tooltip(
          message: id == null ? 'Sync first' : 'Email work order',
          child: IconButton(
            icon: const Icon(Icons.email_outlined),
            onPressed: id != null ? () => _email(id) : null,
          ),
        ),
      ],
    );
  }
}
```

Note: the PDF spinner shows while the fetch runs. In the test, `Icons.picture_as_pdf_outlined` is found because nothing is tapped.

- [ ] **Step 5: Add it to the detail screen** — in `work_order_detail_screen.dart`, add `import '../widgets/work_order_document_actions.dart';` and in `WorkOrderDetailScreen.build` change the AppBar to:

```dart
      appBar: AppBar(
        title: Text(id == null ? 'Work order — pending' : 'WO $id'),
        actions: [WorkOrderDocumentActions(trackId: id)],
      ),
```

- [ ] **Step 6: Run the tests and analyze**

Run: `flutter test test/features/work_orders/ test/core/documents/ test/features/certification/` → all PASS (the existing detail screen tests still pass: a queued job's buttons are disabled and take no input)
Run: `flutter analyze` → No issues found
Run: `dart format lib test` → no unexpected changes beyond formatting

- [ ] **Step 7: Full suite**

Run: `flutter test` → all PASS

- [ ] **Step 8: Commit**

```bash
git add lib/features/work_orders test/features/work_orders
git commit -m "feat(work-orders): View PDF and Email on a synced work order"
```

---

### Task 5: Hand over and record

- [ ] **Step 1:** Update `CLAUDE.md` — under "Work Orders — capture on site" add one line: "View PDF and Email on a synced work order (2026-10-02) — `WorkOrderDocumentActions`; needs the Go side in `docs/go-requirements-work-order-email.md` (until then the server refuses with a 403 sentence)." Under the certification module, change `_EmailDialog` mentions (if any) to `EmailDocumentDialog` in `lib/core/documents/`.
- [ ] **Step 2:** In `CLAUDE.md`'s plan table, add `2026-10-02-work-order-email.md` — ✅ Built, waits on the Go side.
- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: work order email built, waits on the Go side"
```

- [ ] **Step 4:** Launch on the emulator (`flutter run -d emulator-5554`) and hand over to the user to try. Do not tap through it yourself. Expected on today's `demo`: the buttons appear on WO 7144, and View PDF shows the server's refusal sentence until the Go work is deployed.
