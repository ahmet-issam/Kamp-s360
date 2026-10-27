"""Compile library feature against explicit app interfaces and real Flutter dependencies."""
from pathlib import Path
import importlib.util
import shutil
import sys
repo = Path(__file__).resolve().parents[2]
root = Path('library_flutter_check').resolve()
# Reuse the documented tasks harness for the existing models and reminder service.
sys.argv = ['prepare_flutter_harness.py', str(root)]
spec = importlib.util.spec_from_file_location('task_harness', repo / 'tasks_update/test_support/prepare_flutter_harness.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
shutil.copytree(repo / 'library_update/lib', root / 'lib', dirs_exist_ok=True)
shutil.copytree(repo / 'library_update/scripts', root / 'scripts', dirs_exist_ok=True)
spec = importlib.util.spec_from_file_location('library_installer', repo / 'library_update/install_library.py')
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)
for path, patcher in [('lib/core/task_rules.dart', installer.patch_rules), ('lib/core/task_reminder_service.dart', installer.patch_service)]:
    file = root / path
    file.write_text(patcher(file.read_text()), encoding='utf-8')
pubspec = root / 'pubspec.yaml'
pubspec.write_text(pubspec.read_text().replace('dev_dependencies:', '  http: ^1.2.0\n  shared_preferences: ^2.3.0\n  url_launcher: ^6.3.0\ndev_dependencies:'))
# Existing task mocks remain intentionally limited to controller interfaces.
controller = root / 'lib/core/app_controller.dart'
controller.write_text(controller.read_text().replace('bool signedIn = true;', "bool signedIn = true;\n  bool syncing = false;\n  String? lastSyncError;\n  bool hasPendingChanges = false;\n  Future<bool> syncNow() async => true;"))
shutil.copy2(repo / 'library_update/test_support/library_test.dart', root / 'test/library_test.dart')
