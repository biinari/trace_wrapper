# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- [BREAKING CHANGE] `:visibility` option to `wrap()` changed to just indicate the lowest visibility level wanted [commit](https://github.com/biinari/trace_wrapper/commit/84024964d846ed522192d4c1f0a8ecbb8f516323)
- Moved shell colour internals to separate, undocumented module. [commit](https://github.com/biinari/trace_wrapper/7d4a9cb04314e252c4bfd184ce815b300d1f7852)

### Documentation
- Fixed documentation to include `README.md`.
- Added description of `#wrap` behaviour with / without a block.

## [0.1.0] - 2020-04-17

Initial public release

### Changed

- Changed `:method_type` choices to `:instance` (instance methods), `:self`
  (class / module methods, i.e. methods called directly on receiver), `:all`
  (both instance and direct methods)

### Added

- Allow passing `receivers` as an array in first argument to `wrap()`. [commit](https://github.com/biinari/trace_wrapper/3d16a0fa823219705a1214114016d8f66e820609)
- Add `:visibility` option to `wrap()` [PR #1](https://github.com/biinari/trace_wrapper/pulls/1)
- Add `[process:thread]` identifier to trace output when calls are made on a
  different process / thread to the instantiation of `TraceWrapper`.

## 0.0.1 (never released)

[Initial commit](https://github.com/biinari/tree/f71416e97ce3b7c1e76d0d6722ea64eb4d2a01ff)

[Unreleased]: https://github.com/biinari/trace_wrapper/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/biinari/trace_wrapper/releases/tag/v0.1.0
