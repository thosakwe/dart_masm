library masm;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:barback/barback.dart';
import 'package:merge_map/merge_map.dart';
import 'package:path/path.dart' as path;

final Map _defaultMlConfig = {
  "c": true,
  "coff": true,
  "Cp": true
};

final Map _defaultLinkConfig = {
  "SUBSYSTEM": "CONSOLE",
  "LIBPATH": r"C:\masm32\lib"
};

List<String> _buildOpts(Map config, AssetId assetId) {
  List<String> result = [];

  for (String key in config.keys) {
    var value = config[key];

    if (value == true) {
      result.add("/$key");
    } else if (value is String) {
      result.add("/$key:$value");
    }
  }

  var fileName = path.join(
      Directory.current.absolute.path, "build", "${assetId.path}")
      .replaceAll("/", "\\");

  if (!(new File(fileName).existsSync())) {
    stderr.writeln("warning: file does not exist - \"$fileName\"");
  }

  return result..add("$fileName");
}

class MasmTransformer extends Transformer {
  final BarbackSettings _settings;
  String masmPath;

  MasmTransformer.asPlugin(this._settings) {
    masmPath = _settings.configuration['masm_path'] ?? "C:\\masm32";
  }

  @override String get allowedExtensions => ".asm";

  _printStream(Stream<List<int>> input, [IOSink output]) async {
    var sink = output ?? stdout;
    await input.forEach(sink.add);
  }

  _getPath(Asset asset, String extension) =>
      path.join(Directory.current.absolute.path, "build", "${asset.id
          .changeExtension(extension)
          .path}").replaceAll("/", "\\");

  _runMl(Asset asset) async {
    var config = mergeMap(
        [_defaultMlConfig, _settings.configuration['ml'] ?? {}]);
    var opts = _buildOpts(config, asset.id);

    print("Starting ML with these options: $opts");

    var ml = await Process.start("$masmPath\\bin\\ml", opts,
        workingDirectory: path.join(
            Directory.current.absolute.path, "build/web"));

    print("Running ML...");
    int code = await ml.exitCode;

    await _printStream(ml.stdout);
    await _printStream(ml.stderr, stderr);
    print("ML exit code: $code");

    if (code != 0) {
      stderr.writeln(
          "Assembly to object file failed with exit code $code. Check output for details.");
      throw new Exception();
    }

    // Copy and move .obj file
    String objFilename = path.basename(asset.id
        .changeExtension(".obj")
        .path);
    objFilename = path.join(Directory.current.absolute.path, objFilename);
    var obj = new File(objFilename);

    print("Now searching for object file \"${obj.absolute.path}\"");
    if (await obj.exists()) {
      var objPath = _getPath(asset, ".obj");
      print("Copying to \"$objPath}\"");
      await obj.copy(_getPath(asset, ".obj"));
      print("Deleting...");
      await obj.delete();
      print("Deleted.");
    } else print("Not found.");
  }

  _runLink(Asset asset) async {
    var config = mergeMap(
        [_defaultLinkConfig, _settings.configuration['link'] ?? {}]);
    config["OUT"] = _getPath(asset, ".exe");
    var opts = _buildOpts(config, asset.id.changeExtension(".obj"));

    print("Starting LINK with these options: $opts");

    var link = await Process.start("$masmPath\\bin\\link", opts,
        workingDirectory: path.join(
            Directory.current.absolute.path, "build/web"));

    print("Running LINK...");
    int code = await link.exitCode;
    await _printStream(link.stdout);
    await _printStream(link.stderr, stderr);
    print("LINK exit code: $code");

    if (code != 0) {
      stderr.writeln(
          "Linking to executable failed with exit code $code. Check output for details.");
      throw new Exception();
    }
  }

  @override
  apply(Transform transform) async {
    if (!Platform.isWindows) {
      stderr.writeln("Whoops! You can only run this transformer on Windows.");
      throw new Exception();
    }

    print("Getting ready to compile Assembly from project: ${Directory.current
        .absolute.path}");
    var asset = transform.primaryInput;

    var fileName = path.join(
        Directory.current.absolute.path, "build", "${asset.id.path}");
    var file = new File(fileName);

    if (!(await file.exists())) {
      var stream = asset.read();
      await file.create(recursive: true);
      await stream.pipe(file.openWrite());
    }

    print("Loaded MASM file: \"$fileName\"");

    await _runMl(asset);
    print("ML build task done.");

    await _runLink(asset);
    print("LINK build task done.");


    var executable = new File(_getPath(asset, ".exe"));

    if (await executable.exists()) {
      transform.addOutput(new Asset.fromFile(asset.id.changeExtension(".exe"), executable));
      print("Compiled ${asset.id.path} to ${executable.absolute.path}");

      if (_settings.configuration['run'] == true) {
        var process = await Process.start(executable.absolute.path,
            _settings.configuration['run_args'] ?? []);
        int code = await process.exitCode;
        _printStream(process.stdout);
        _printStream(process.stderr, stderr);

        print("Execution of ${path.basename(executable.path)} completed with exit code $code.");
      }
    }

    else {
      stderr.writeln(
          "For some reason, no executable was created. Check the output for details.");
      stderr.writeln("No \"${executable.absolute.path}\" exists.");
      throw new Exception();
    }
  }
}