# ips2crashlog

Command line tool that converts Apple generated .ips crash logs to human readable format in the exact same way as Xcode and Console.app do.

## Build

```bash
swift build -c release
```

## Build on Linux

```bash
swift build -Xswiftc -static-stdlib -c release -v
```

## Usage

```bash
USAGE: ips2crashlog <input> [--output <output>]

ARGUMENTS:
  <input>                 Path to the IPS crash report file

OPTIONS:
  -o, --output <output>   Output path (optional)
  -h, --help              Show help information.
```

## Tests

The suite of tests is currently one test that compares the output of the tool with the output of Console.app.

```bash
swift test
```

## Tests on Linux

```bash
swift test -v
```

## GitHub Actions Workflow

The `linux-build` job in the GitHub Actions workflow is configured to build and upload an artifact on Linux.

