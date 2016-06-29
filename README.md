# dart_masm
Pub transformer that compiles .asm files to .exe.

# About
I created this for use with my experiment [WinDart](https://github.com/thosakwe/windart), to have Dart files in my `web` directory
compiled to MASM Assembly, and then assembled and linked to .exe files.

# Installation
You will need MASM32 installed, and it to be installed to C:\masm32. Alternatively, you can pass an `masm_path` in the configuration,
and ML and LINK will be run from that directory.

```yaml
dependencies:
  masm: ^1.0.0-dev needs
```

# Usage
This library is a transformer, and supports some options.

```yaml
transformers:
- windart
- masm
```

Supported options:
* **run** (*bool*) - If set to `true`, then the executable will be run on completion.
* **run_args** (*List<String>*) - Can be included to pass them to resulting executable.
* **ml** (*Map*) - Options to pass to ML. Option values should be strings, or `true`.
* **link** - Same as **ml** (above), but these will be passed to LINK.
* **masm_path** (*String*) - The path to the MASM installation. Default: `"C:\\masm32"`

Defaults:

```yaml
run: false
ml:
  c: true
  coff: true
  Cp: true
link:
  SUBSYTEM: CONSOLE
  LIBPATH: "C:\\masm32\\lib"
```
