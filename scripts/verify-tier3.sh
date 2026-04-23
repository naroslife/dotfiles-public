#!/usr/bin/env bash
# scripts/verify-tier3.sh
# Deep verification tests for Tier 3 complex toolchains
# Validates not just binary presence but actual path resolution and functionality
#
# Usage:
#   ./scripts/verify-tier3.sh
#   ./scripts/verify-tier3.sh --verbose
#   mise run tier3-verify

set -euo pipefail

VERBOSE=false
[[ "${1:-}" == "--verbose" ]] && VERBOSE=true

PASS=0
FAIL=0
WARN=0
SKIP=0

log_pass() { echo "  ✓ $*"; ((PASS++)) || true; }
log_fail() { echo "  ✗ $*" >&2; ((FAIL++)) || true; }
log_warn() { echo "  ! $*"; ((WARN++)) || true; }
log_skip() { echo "  - $*"; ((SKIP++)) || true; }
log_info() { echo "$*"; }

# Detect WSL2 (rr and perf-tools have no perf_event support there)
IS_WSL=false
if [[ -f /proc/version ]] && grep -qi microsoft /proc/version; then
  IS_WSL=true
fi

log_info "=== Tier 3 Toolchain Verification ==="
[[ "${IS_WSL}" == true ]] && log_info "(WSL2 detected — rr and perf-tools will be skipped)"
log_info ""

# ── GDB (GNU Debugger) ────────────────────────────────────────────────────────
# Path deps: share/gdb/python/, share/gdb/auto-load/, data-directory
# Install: apt install gdb
log_info "── GDB ──"
if command -v gdb &>/dev/null; then
  # Python scripting support — loads share/gdb/python/
  if gdb -batch -ex "python print('ok')" 2>/dev/null | grep -q "^ok$"; then
    log_pass "gdb: Python scripting support works"
  else
    log_fail "gdb: Python scripting not working (reinstall: sudo apt install --reinstall gdb)"
  fi

  # data-directory — must resolve to a valid path
  data_dir_line=$(gdb -batch -ex "show data-directory" 2>/dev/null || echo "")
  data_dir=$(echo "${data_dir_line}" | grep -oP '(?<=")(/[^"]+)' | head -1 || echo "")
  if [[ -n "${data_dir}" ]] && [[ -d "${data_dir}" ]]; then
    log_pass "gdb: data-directory resolves (${data_dir})"
  else
    log_warn "gdb: could not verify data-directory (output: ${data_dir_line})"
  fi
else
  log_fail "gdb: not found (install: sudo apt install gdb)"
fi

# ── CMake ─────────────────────────────────────────────────────────────────────
# Path deps: share/cmake-*/Modules/, share/cmake-*/Templates/
# Install: apt install cmake (managed by apt, not mise — avoids PATH ambiguity)
log_info ""
log_info "── CMake ──"
if command -v cmake &>/dev/null; then
  [[ "${VERBOSE}" == true ]] && log_pass "cmake: $(cmake --version 2>/dev/null | head -1)" \
    || log_pass "cmake: installed"

  # Verify module data accessible — validates share/cmake-*/Modules/ is present
  if cmake --help-module FindThreads &>/dev/null; then
    log_pass "cmake: FindThreads module accessible (Modules/ dir present)"
  else
    log_fail "cmake: cannot access FindThreads module (incomplete cmake installation)"
  fi

  # find-package mode (deprecated cmake 3.14+ but still validates module resolution)
  tmpdir=$(mktemp -d)
  if cmake --find-package -DNAME=Threads -DCOMPILER_ID=GNU -DLANGUAGE=C -DMODE=EXIST \
       -B "${tmpdir}" &>/dev/null 2>&1; then
    log_pass "cmake: find-package mode resolves Threads"
  else
    log_warn "cmake: --find-package deprecated in this version — Modules/ dir check passed above"
  fi
  rm -rf "${tmpdir}"
else
  log_fail "cmake: not found (install: sudo apt install cmake)"
fi

# ── GCC / G++ ─────────────────────────────────────────────────────────────────
# Path deps: include/, lib/, libexec/cc1, lib/gcc/x86_64-linux-gnu/*/
# Install: apt install gcc g++ build-essential
log_info ""
log_info "── GCC / G++ ──"
if command -v gcc &>/dev/null; then
  if echo 'int main(){}' | gcc -x c - -o /dev/null 2>/dev/null; then
    log_pass "gcc: C compilation works"
  else
    log_fail "gcc: C compilation failed (check: gcc -v)"
  fi
else
  log_fail "gcc: not found (install: sudo apt install gcc build-essential)"
fi

if command -v g++ &>/dev/null; then
  if echo 'int main(){}' | g++ -x c++ - -o /dev/null 2>/dev/null; then
    log_pass "g++: C++ compilation works"
  else
    log_fail "g++: C++ compilation failed (check: g++ -v)"
  fi
else
  log_fail "g++: not found (install: sudo apt install g++)"
fi

# ── clang-tools ───────────────────────────────────────────────────────────────
# Path deps: lib/clang/*/include/ (resource directory relative to binary)
# Install: apt install clang-format clang-tidy
log_info ""
log_info "── clang-tools (clang-format, clang-tidy) ──"
if command -v clang-format &>/dev/null; then
  # Pipe valid C++ to clang-format — must not error about missing resource dir
  if echo '{}' | clang-format &>/dev/null; then
    log_pass "clang-format: no missing resource dir error"
  else
    log_fail "clang-format: failed — possibly missing lib/clang/*/include/"
  fi
else
  log_fail "clang-format: not found (install: sudo apt install clang-format)"
fi

if command -v clang-tidy &>/dev/null; then
  if clang-tidy --version &>/dev/null; then
    log_pass "clang-tidy: available"
  else
    log_fail "clang-tidy: binary present but --version failed"
  fi
else
  log_fail "clang-tidy: not found (install: sudo apt install clang-tidy)"
fi

# ── Valgrind ──────────────────────────────────────────────────────────────────
# Path deps: lib/valgrind/ (tool binaries: memcheck, cachegrind, etc.)
# Install: apt install valgrind
log_info ""
log_info "── Valgrind ──"
if command -v valgrind &>/dev/null; then
  if valgrind --version &>/dev/null; then
    log_pass "valgrind: $(valgrind --version 2>/dev/null | head -1)"
  else
    log_fail "valgrind: --version failed"
  fi

  if command -v gcc &>/dev/null; then
    tmpbin=$(mktemp /tmp/valgrind-test.XXXXXX)
    if echo 'int main(){}' | gcc -x c - -g -o "${tmpbin}" 2>/dev/null \
       && valgrind --error-exitcode=1 --quiet "${tmpbin}" 2>/dev/null; then
      log_pass "valgrind: memcheck functional test passed"
    else
      log_warn "valgrind: functional test failed (may need ptrace permissions)"
    fi
    rm -f "${tmpbin}"
  else
    log_warn "valgrind: skipping functional test (gcc not available)"
  fi
else
  log_fail "valgrind: not found (install: sudo apt install valgrind)"
fi

# ── LLDB ──────────────────────────────────────────────────────────────────────
# Path deps: Python scripting support, LLVM shared libs
# Install: apt install lldb
log_info ""
log_info "── LLDB ──"
if command -v lldb &>/dev/null; then
  log_pass "lldb: $(lldb --version 2>/dev/null | head -1)"
else
  log_fail "lldb: not found (install: sudo apt install lldb)"
fi

# ── rr (record-replay debugger) ───────────────────────────────────────────────
# Path deps: lib/rr/ (shared libs), kernel perf_event support
# Install: apt install rr (if available), else build from source
# WSL2 limitation: no perf_event support — native Linux only
log_info ""
log_info "── rr (record-replay debugger) ──"
if [[ "${IS_WSL}" == true ]]; then
  log_skip "rr: WSL2 has no perf_event support — native Linux only"
  log_skip "rr: native fix: sudo sysctl kernel.perf_event_paranoid=1"
elif command -v rr &>/dev/null; then
  if rr --version &>/dev/null; then
    log_pass "rr: $(rr --version 2>/dev/null | head -1)"
    perf_paranoid=$(cat /proc/sys/kernel/perf_event_paranoid 2>/dev/null || echo "unknown")
    if [[ "${perf_paranoid}" != "unknown" ]] && [[ "${perf_paranoid}" -le 1 ]]; then
      log_pass "rr: kernel.perf_event_paranoid=${perf_paranoid} (acceptable for rr)"
    else
      log_warn "rr: kernel.perf_event_paranoid=${perf_paranoid} — rr requires <= 1"
      log_warn "rr: fix: sudo sysctl kernel.perf_event_paranoid=1"
    fi
  else
    log_warn "rr: binary present but --version failed"
  fi
else
  log_warn "rr: not installed (optional — not available on all Ubuntu versions)"
  log_warn "rr: see https://github.com/rr-debugger/rr for install instructions"
fi

# ── Build system tools ────────────────────────────────────────────────────────
# Path deps: share/aclocal/, share/autoconf/, share/automake-*/
# Install: apt install autoconf automake libtool
log_info ""
log_info "── Build system tools (autoconf, automake, libtool) ──"
for tool in autoconf automake libtool; do
  if command -v "${tool}" &>/dev/null; then
    if [[ "${VERBOSE}" == true ]]; then
      log_pass "${tool}: $("${tool}" --version 2>/dev/null | head -1)"
    else
      log_pass "${tool}"
    fi
  else
    log_fail "${tool}: not found (install: sudo apt install ${tool})"
  fi
done

# ── strace / ltrace ───────────────────────────────────────────────────────────
# Install: apt install strace ltrace
log_info ""
log_info "── System tracers (strace, ltrace) ──"
if command -v strace &>/dev/null; then
  if strace -c echo hello &>/dev/null 2>&1; then
    log_pass "strace: functional"
  else
    log_warn "strace: installed but may need ptrace permissions (ptrace_scope)"
  fi
else
  log_fail "strace: not found (install: sudo apt install strace)"
fi

if command -v ltrace &>/dev/null; then
  log_pass "ltrace: available"
else
  log_fail "ltrace: not found (install: sudo apt install ltrace)"
fi

# ── perf tools ────────────────────────────────────────────────────────────────
# Path deps: kernel-version-specific, needs matching kernel headers
# Install: apt install linux-tools-$(uname -r)
# WSL2 limitation: no perf_event support
log_info ""
log_info "── perf tools ──"
if [[ "${IS_WSL}" == true ]]; then
  log_skip "perf: WSL2 has no perf_event support"
  log_skip "perf: native Linux install: sudo apt install linux-tools-\$(uname -r)"
elif command -v perf &>/dev/null; then
  log_pass "perf: available"
else
  kernel_ver=$(uname -r)
  log_warn "perf: not found for kernel ${kernel_ver}"
  log_warn "perf: install: sudo apt install linux-tools-${kernel_ver}"
fi

# ── JDK 17 + Maven + Gradle ───────────────────────────────────────────────────
# Path deps: bin/, lib/, include/, jmods/, conf/
# Install: mise install java@temurin-17
# Env vars: JAVA_HOME (set by mise activate), MAVEN_OPTS=-Xmx1024m
log_info ""
log_info "── JDK 17 + Maven + Gradle (mise: java@temurin-17) ──"
if command -v java &>/dev/null; then
  log_pass "java: $(java -version 2>&1 | head -1)"

  if command -v javac &>/dev/null; then
    log_pass "javac: $(javac -version 2>&1)"
  else
    log_fail "javac: not found (JRE only? Need full JDK — mise install java@temurin-17)"
  fi

  if [[ -n "${JAVA_HOME:-}" ]] && [[ -d "${JAVA_HOME}" ]]; then
    log_pass "JAVA_HOME=${JAVA_HOME} (set by mise activate)"
  else
    log_fail "JAVA_HOME: not set or invalid"
    log_fail "  ensure 'eval \$(mise activate zsh)' is in ~/.zshrc (not shims mode)"
  fi
else
  log_fail "java: not found (install: mise install java@temurin-17)"
fi

if command -v mvn &>/dev/null; then
  log_pass "maven (mvn): $(mvn --version 2>/dev/null | head -1)"
else
  log_fail "maven: not found (install: mise install maven)"
fi

if command -v gradle &>/dev/null; then
  gradle_ver=$(gradle --version 2>/dev/null | grep "^Gradle" | head -1 || echo "available")
  log_pass "gradle: ${gradle_ver}"
else
  log_fail "gradle: not found (install: mise install gradle)"
fi

# ── Go ────────────────────────────────────────────────────────────────────────
# Path deps: GOROOT/pkg/, GOROOT/src/ (standard library source)
# Install: mise install go
# Env vars: GOPATH=~/go, GOBIN=~/go/bin
log_info ""
log_info "── Go (mise: go) ──"
if command -v go &>/dev/null; then
  log_pass "go: $(go version 2>/dev/null)"

  goroot=$(go env GOROOT 2>/dev/null || echo "")
  if [[ -n "${goroot}" ]] && [[ -d "${goroot}/src" ]]; then
    log_pass "go: GOROOT=${goroot} (standard library source present)"
  else
    log_fail "go: GOROOT=${goroot:-unset} missing src/ (incomplete installation)"
  fi
else
  log_fail "go: not found (install: mise install go)"
fi

# ── Node.js ───────────────────────────────────────────────────────────────────
# Path deps: lib/node_modules/ (npm ships with node)
# Install: mise install node@lts
# Env vars: NPM_CONFIG_PREFIX=~/.npm-global
log_info ""
log_info "── Node.js (mise: node@lts) ──"
if command -v node &>/dev/null; then
  log_pass "node: $(node --version 2>/dev/null)"

  if command -v npm &>/dev/null; then
    log_pass "npm: $(npm --version 2>/dev/null)"
  else
    log_fail "npm: not found (should ship with node — reinstall: mise install node)"
  fi

  if command -v npx &>/dev/null; then
    log_pass "npx: $(npx --version 2>/dev/null)"
  else
    log_warn "npx: not found (should ship with node@lts)"
  fi
else
  log_fail "node: not found (install: mise install node)"
fi

# ── Rust / rustup ─────────────────────────────────────────────────────────────
# Path deps: toolchains, sysroot, target triples in RUSTUP_HOME
# Install: mise install rust
# Env vars: CARGO_HOME=~/.cargo, RUSTUP_HOME=~/.rustup
log_info ""
log_info "── Rust / rustup (mise: rust) ──"
if command -v rustc &>/dev/null; then
  log_pass "rustc: $(rustc --version 2>/dev/null)"

  if command -v cargo &>/dev/null; then
    log_pass "cargo: $(cargo --version 2>/dev/null)"
  else
    log_fail "cargo: not found (reinstall: mise install rust)"
  fi

  if command -v rustup &>/dev/null; then
    active=$(rustup show active-toolchain 2>/dev/null | head -1 || echo "available")
    log_pass "rustup: ${active}"
  else
    log_warn "rustup: not in PATH (expected at \${CARGO_HOME}/bin/rustup)"
  fi
else
  log_fail "rustc: not found (install: mise install rust)"
fi

# ── Python 3 ──────────────────────────────────────────────────────────────────
# Path deps: lib/python3.*/, site-packages, venv support
# Install: mise install python@3.12
log_info ""
log_info "── Python 3 (mise: python@3.12) ──"
if command -v python3 &>/dev/null; then
  log_pass "python3: $(python3 --version 2>/dev/null)"

  venv_dir=$(mktemp -d /tmp/python-venv-test.XXXXXX)
  if python3 -m venv "${venv_dir}" &>/dev/null; then
    log_pass "python3: venv creation works"
  else
    log_fail "python3: venv creation failed (missing venv support)"
  fi
  rm -rf "${venv_dir}"
else
  log_fail "python3: not found (install: mise install python@3.12)"
fi

# ── Bazel ─────────────────────────────────────────────────────────────────────
# Install: mise install (via aqua:bazelbuild/bazel)
log_info ""
log_info "── Bazel (mise: aqua:bazelbuild/bazel) ──"
if command -v bazel &>/dev/null; then
  bazel_ver=$(bazel version 2>/dev/null | grep "Build label" | head -1 || echo "available")
  log_pass "bazel: ${bazel_ver}"
else
  log_warn "bazel: not found (optional — install: mise install)"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
log_info ""
log_info "=== Summary ==="
log_info "  Passed:   ${PASS}"
log_info "  Warnings: ${WARN}"
log_info "  Failed:   ${FAIL}"
log_info "  Skipped:  ${SKIP}"
log_info ""

if [[ "${FAIL}" -gt 0 ]]; then
  log_info "Some Tier 3 tools failed verification."
  log_info "  apt tools:  sudo apt install <package>"
  log_info "  mise tools: mise install"
  exit 1
fi

if [[ "${WARN}" -gt 0 ]]; then
  log_info "All required checks passed — review warnings above."
  exit 2
fi

log_info "All Tier 3 toolchain checks passed!"
exit 0
