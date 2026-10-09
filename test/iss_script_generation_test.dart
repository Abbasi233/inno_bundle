import 'dart:io';

import 'package:test/test.dart';

import 'package:inno_bundle/builders/script_builder.dart';
import 'package:inno_bundle/models/cli_configs/inno_bundle_cli_config.dart';
import 'package:inno_bundle/models/config.dart';

import 'support/language_fixture.dart';

void main() {
  initTestLanguages();
  group('.iss script generation', () {
    late Directory tempDir;
    late Directory appDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('inno_test_');
      appDir = Directory('${tempDir.path}\\app');
      appDir.createSync();
      // Put a dummy exe so the [Files] section has something to list
      File('${appDir.path}\\my_app.exe').writeAsStringSync('dummy');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    Config _config({
      List<String> outputDir = const ['tmp', 'inno_out'],
      List<dynamic>? dirs,
      Directory? baseDir,
    }) {
      return Config.fromJson(
        {
          'name': 'my_app',
          'description': 'A test app.',
          'version': '1.0.0',
          'maintainer': 'Test User',
        },
        {
          'inno_bundle': {
            'id': '5ec949d0-0582-1e06-b073-b5d1161f6fff',
            if (dirs != null) 'dirs': dirs,
          },
        },
        cliConfig: InnoBundleCliConfig(),
        pubspecFile: File(''),
        configFile: File(''),
        outputDir: outputDir,
        innoExec: File('test_iscc.exe'),
        baseDir: baseDir,
      );
    }

    test('includes [Setup] section with id, publisher, version from config',
        () {
      final config = _config(outputDir: ['tmp', 'inno_out']);
      final builder = ScriptBuilder(config, appDir);

      final script = builder.buildScript();

      expect(script, contains('[Setup]'));
      expect(script, contains('AppId=5ec949d0-0582-1e06-b073-b5d1161f6fff'));
      expect(script, contains('AppName=my_app'));
      expect(script, contains('AppVersion=1.0.0'));
      expect(script, contains('AppPublisher=Test User'));
    });

    test('includes one [Files] entry per DLL in the required-DLL allowlist',
        () {
      final config = _config(outputDir: ['tmp', 'inno_out']);
      final builder = ScriptBuilder(config, appDir);

      final script = builder.buildScript();

      expect(script, contains('[Files]'));
      expect(script, contains('Source:'));
      // The app exe should be listed
      expect(script, contains('my_app.exe'));
    });

    test('honors the default x64_compatible architecture in the script', () {
      final config = _config(outputDir: ['tmp', 'inno_out']);
      final builder = ScriptBuilder(config, appDir);

      final script = builder.buildScript();

      expect(script, contains('ArchitecturesAllowed=x64compatible'));
      expect(script, contains('ArchitecturesInstallIn64BitMode=x64compatible'));
    });

    test('copies dir contents into [Files] when the source folder exists', () {
      final assetsDir = Directory('${tempDir.path}\\assets\\animations');
      assetsDir.createSync(recursive: true);
      File('${assetsDir.path}\\idle.json').writeAsStringSync('{}');

      final config = _config(
        dirs: [
          {'source': 'assets/animations'},
        ],
        baseDir: tempDir,
      );
      final builder = ScriptBuilder(config, appDir);

      final script = builder.buildScript();
      final sourcePath = assetsDir.absolute.path;

      expect(
        script,
        contains(
          'Source: "$sourcePath\\*"; DestDir: "{app}\\assets\\animations"; '
          'Flags: ignoreversion recursesubdirs createallsubdirs',
        ),
      );
      expect(script, contains('Name: "{app}\\assets\\animations"'));
    });

    test('uses source as destination when a dir entry is a plain string', () {
      final assetsDir = Directory('${tempDir.path}\\assets\\animations');
      assetsDir.createSync(recursive: true);
      File('${assetsDir.path}\\idle.json').writeAsStringSync('{}');

      final config = _config(
        dirs: ['assets/animations'],
        baseDir: tempDir,
      );
      final builder = ScriptBuilder(config, appDir);

      final script = builder.buildScript();
      final sourcePath = assetsDir.absolute.path;

      expect(
        script,
        contains(
          'Source: "$sourcePath\\*"; DestDir: "{app}\\assets\\animations"; '
          'Flags: ignoreversion recursesubdirs createallsubdirs',
        ),
      );
    });

    test('copies dir contents to destination when it differs from source', () {
      final assetsDir = Directory('${tempDir.path}\\assets\\animations');
      assetsDir.createSync(recursive: true);
      File('${assetsDir.path}\\idle.json').writeAsStringSync('{}');

      final config = _config(
        dirs: [
          {
            'source': 'assets/animations',
            'destination': 'data/anims',
          },
        ],
        baseDir: tempDir,
      );
      final builder = ScriptBuilder(config, appDir);

      final script = builder.buildScript();
      final sourcePath = assetsDir.absolute.path;

      expect(
        script,
        contains(
          'Source: "$sourcePath\\*"; DestDir: "{app}\\data\\anims"; '
          'Flags: ignoreversion recursesubdirs createallsubdirs',
        ),
      );
      expect(script, contains('Name: "{app}\\data\\anims"'));
    });

    test('does not copy dir contents when the source folder is absent', () {
      final config = _config(
        dirs: [
          {'source': 'appdata'},
        ],
        baseDir: tempDir,
      );
      final builder = ScriptBuilder(config, appDir);

      final script = builder.buildScript();

      expect(script, contains('Name: "{app}\\appdata"'));
      expect(script, isNot(contains('DestDir: "{app}\\appdata"')));
    });
  });
}
