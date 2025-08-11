#!/usr/bin/env bash
# audit-signing.sh (quiet, slice-aware, bash 3.2 compatible)
# Usage: ./audit-signing.sh "/path/to/Your.app"

set -euo pipefail

APP="${1:-}"
if [[ -z "$APP" || ! -d "$APP" ]]; then
  echo "Usage: $0 /path/to/App.app" >&2
  exit 2
fi

run_quiet() { "$@" >/dev/null 2>&1; }

err=0

leaf_auth() {
  codesign --display --verbose=4 "$1" 2>&1 | awk -F'= *' '/^Authority=/{print $2; exit}'
}

is_macho() {
  file -b "$1" | grep -q 'Mach-O'
}

verify_slice() {
  local p="$1" arch="$2"
  if ! run_quiet codesign --verify --strict --verbose=2 --arch "$arch" "$p"; then
    echo "❌ UNSIGNED/invalid slice [$arch]: $p"
    err=1
    return 1
  fi
}

verify_one() {
  local p="$1" expect="$2" kind="$3"

  if ! run_quiet codesign --verify --strict --verbose=2 "$p"; then
    echo "❌ UNSIGNED or invalid: [$kind] $p"
    err=1
    return
  fi

  if is_macho "$p"; then
    local arches
    arches="$(lipo -archs "$p" 2>/dev/null || true)"
    if [[ -n "$arches" ]]; then
      for arch in $arches; do
        verify_slice "$p" "$arch" || true
      done
    fi
  fi

  local leaf
  leaf="$(leaf_auth "$p" || true)"
  if [[ -z "${leaf:-}" ]]; then
    echo "❌ No Authority: [$kind] $p"
    err=1
    return
  fi

  if [[ "$leaf" != "$expect" ]]; then
    echo "❌ MISMATCH Authority: [$kind] $p"
    echo "   found:  $leaf"
    echo "   expect: $expect"
    err=1
  else
    echo "✅ OK [$kind] $p — $leaf"
  fi
}

echo "==> Checking app: $APP"

if ! run_quiet codesign --verify --strict --verbose=2 "$APP"; then
  echo "❌ App bundle is not properly signed: $APP"
  exit 1
fi

APP_LEAF="$(leaf_auth "$APP" || true)"
if [[ -z "${APP_LEAF:-}" ]]; then
  echo "❌ Could not read app's Authority."
  exit 1
fi
echo "App leaf Authority: $APP_LEAF"
echo

gather_paths() {
  local app="$1"
  {
    [[ -d "$app/Contents/MacOS" ]] && \
      find "$app/Contents/MacOS" -type f -perm -u+x -print0 2>/dev/null
    [[ -d "$app/Contents/Frameworks" ]] && {
      find "$app/Contents/Frameworks" -type d -name "*.framework" -prune -print0 2>/dev/null
      find "$app/Contents/Frameworks" -type f -name "*.dylib" -print0 2>/dev/null
    }
    [[ -d "$app/Contents/Resources" ]] && \
      find "$app/Contents/Resources" -type f -perm -u+x -print0 2>/dev/null
  } | tr '\0' '\n' | awk 'NF' | sort -u
}

while IFS= read -r p; do
  # Classify for nicer messages
  kind="Exec"
  if [[ -d "$p" ]]; then
    kind="Bundle"
    [[ "$p" == *"/Contents/Frameworks/"*".framework" ]] && kind="Framework"
  else
    [[ "$p" == *"/Contents/Resources/"* ]] && kind="ResourceExec"
    [[ "$p" == *"/Contents/MacOS/"* ]] && kind="MainExec"
    [[ "$p" == *"/Contents/Frameworks/"*".dylib" ]] && kind="Dylib"
  fi
  verify_one "$p" "$APP_LEAF" "$kind"
done < <(gather_paths "$APP")

echo
if [[ $err -ne 0 ]]; then
  echo "⛔ Signing audit FAILED."
  exit 1
else
  echo "🎉 Signing audit PASSED. All checked items are signed by: $APP_LEAF"
  exit 0
fi
