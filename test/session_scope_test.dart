import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subako/core/security/permissions.dart';
import 'package:subako/services/ai_assistant_service.dart';
import 'package:subako/services/demo_repository.dart';
import 'package:subako/services/subako_repository.dart';
import 'package:subako/shared/models/enums.dart';
import 'package:subako/shared/models/models.dart';
import 'package:subako/shared/providers/app_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('explicit site grants override coarse role, including Pekaseh', () {
    const user = UserProfile(
      uid: 'u',
      name: 'U',
      email: 'u@example.com',
      role: UserRole.pekaseh,
      siteIds: ['a', 'b'],
      memberships: {
        'a': SiteMembership(
          role: UserRole.pekaseh,
          permissions: {'dashboard.view'},
        ),
        'b': SiteMembership(
          role: UserRole.farmerViewer,
          permissions: {'ledger.view'},
        ),
      },
    );
    expect(
      Permissions.forUser(user.forSite('a'), Permissions.approveRules),
      isFalse,
    );
    expect(user.forSite('b').role, UserRole.farmerViewer);
    expect(
      Permissions.forUser(user.forSite('unknown'), Permissions.viewDashboard),
      isFalse,
    );
  });
  test('session observes external logout; pending chat cannot return to another user', () async {
    final repo = DemoRepository();
    final container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(() {
      container.dispose();
      repo.dispose();
    });
    final auth = container.listen(authControllerProvider, (_, _) {});
    final chat = container.listen(chatControllerProvider, (_, _) {});
    addTearDown(auth.close);
    addTearDown(chat.close);
    await container.read(authControllerProvider.future);
    await container
        .read(authControllerProvider.notifier)
        .signIn(email: 'pekaseh@subako.demo', password: kDemoPassword);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(activeSiteIdProvider), 'site-sangeh');
    final pending = container
        .read(chatControllerProvider.notifier)
        .send(
          prompt: 'Kondisi air?',
          context: AiContext(
            siteId: 'site-sangeh',
            siteName: 'Sangeh',
            telemetrySummary: 'simulasi',
            gateSummary: 'simulasi',
            activeRuleSummary: 'simulasi',
            dataState: 'SIMULATION',
            capturedAt: DateTime.now().toUtc(),
          ),
        );
    await repo.signOut();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(container.read(authControllerProvider).value, isNull);
    expect(container.read(activeSiteIdProvider), isEmpty);
    await pending;
    expect(container.read(chatControllerProvider), isEmpty);
  });
  test('invalid password is returned to login UI as an error', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(authControllerProvider, (_, _) {});
    await container.read(authControllerProvider.future);
    await expectLater(
      container
          .read(authControllerProvider.notifier)
          .signIn(email: 'pekaseh@subako.demo', password: 'wrong-password'),
      throwsA(isA<SubakoException>()),
    );
    expect(container.read(authControllerProvider).hasError, isTrue);
  });
}
