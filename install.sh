#!/bin/bash
# AUTO-GENERATED: Published to GitHub Pages by CI on each tagged release.
# Do not edit the published copy — edit install.sh in the source repository instead.
#
# Installs the latest Open DS MCP Server: the Claude Desktop extension (.mcpb) and, when Claude Code and
# Node.js 20 or later are installed, the same server for Claude Code. macOS only.
#   curl -fsSL https://wpp-jamie-mills.github.io/open-ds-mcp-site/install.sh | bash
# For an AI agent or a script (no terminal: it never prompts, and answers no to every question):
#   curl -fsSL <same url> | OPEN_DS_INSTALL_TTY=/dev/null bash
#
# Environment overrides (mainly for tests):
#   OPEN_DS_MCP_HOME          data folder (--dir wins; default ~/.open-ds-mcp, where the server keeps its cache)
#   OPEN_DS_INSTALL_BASE      base URL for the download files (default: the GitHub Pages site)
#   OPEN_DS_INSTALL_TTY       where prompts are read from (default /dev/tty; /dev/null = no terminal)
#   OPEN_DS_INSTALL_NO_OPEN   1 = don't open Claude Desktop's install dialog
#   OPEN_DS_INSTALL_CLAUDE    the claude command to register with (default: claude on PATH; none = skip Claude Code)
set -euo pipefail

# Default download base (the prerelease copy is rewritten to point at /rc). Exactly one such line.
SITE_BASE_DEFAULT="https://wpp-jamie-mills.github.io/open-ds-mcp-site"

STORYBOOK="https://components.os.wpp.com"
# Where the server keeps the WPP sign-in (OPEN_DS_KEYCHAIN_SERVICE, as the server reads it, for tests).
KEYCHAIN_SERVICE="${OPEN_DS_KEYCHAIN_SERVICE:-open-ds-mcp}"
# How Claude Desktop names the installed extension: local.mcpb.<author>.<manifest name>.
EXTENSION_ID="local.mcpb.jamie-mills.open-ds-mcp"
CLAUDE_BUNDLE_ID="com.anthropic.claudefordesktop"
# The name Claude Code knows the server by.
SERVER_NAME="open-ds"

# Colour only on a terminal, so agent and CI logs stay plain.
if [[ -t 1 && -t 2 ]]; then
  RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' BLUE='\033[0;34m' NC='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

# printf, not echo -e, so backslashes in paths are shown as typed.
print_error() { printf '%b✗ %s%b\n' "$RED" "$1" "$NC" >&2; }
print_success() { printf '%b✓ %s%b\n' "$GREEN" "$1" "$NC"; }
print_warning() { printf '%b⚠ %s%b\n' "$YELLOW" "$1" "$NC"; }
print_step() { printf '%b→ %s%b\n' "$BLUE" "$1" "$NC"; }
die() {
  print_error "$1"
  exit 1
}

OPEN_DS_TEMP_DIR=""
cleanup_temp() {
  if [[ -n "$OPEN_DS_TEMP_DIR" && -d "$OPEN_DS_TEMP_DIR" ]]; then rm -rf "$OPEN_DS_TEMP_DIR"; fi
}

usage() {
  cat <<'EOF'
Open DS MCP Server installer (macOS)

Installs the Claude Desktop extension and, when Claude Code and Node.js 20 or later are installed, adds the same
server to Claude Code (as "open-ds"). Run it again to update.

Usage:
  curl -fsSL https://wpp-jamie-mills.github.io/open-ds-mcp-site/install.sh | bash
  curl -fsSL https://wpp-jamie-mills.github.io/open-ds-mcp-site/install.sh | bash -s -- --status

Options:
  --dir <path>       Data folder (default: ~/.open-ds-mcp). Use the same folder when you update.
  --no-claude-code   Don't add the server to Claude Code.
  --status           Print what is installed and the latest version available, then exit.
  --uninstall        Remove the Claude Code entry and the data folder (asks first; with no terminal, add --yes).
                     Remove the Claude Desktop extension in Claude Desktop: Settings → Extensions.
  --yes              Answer yes to the uninstall question.
  --help             Show this help.

Environment:
  OPEN_DS_MCP_HOME
      Same as --dir (--dir wins).
  OPEN_DS_INSTALL_TTY
      Where questions are read from; /dev/null means no terminal (every answer is no).
  OPEN_DS_INSTALL_BASE
      Where the release files are downloaded from (default: the project site). For testing.
  OPEN_DS_INSTALL_NO_OPEN
      1 = don't open Claude Desktop's install dialog. For testing.
  OPEN_DS_INSTALL_CLAUDE
      The claude command to register with (default: claude on PATH); none = skip Claude Code.
EOF
}

# Physical path of $1 with symlinks resolved in the part that already exists, so the restricted-folder
# checks can't be dodged with symlinks, double slashes or a different spelling.
canonical_path() {
  local path="$1" rest="" dir
  while [[ ! -d "$path" ]]; do
    rest="/${path##*/}$rest"
    path="${path%/*}"
    [[ -n "$path" ]] || path="/"
  done
  dir="$(cd -P "$path" 2>/dev/null && pwd -P)" || return 1
  [[ "$dir" != "/" ]] || dir=""
  printf '%s%s\n' "$dir" "$rest"
}

lowercase() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# Questions are read from the terminal, not stdin (stdin is the script itself under curl | bash).
can_answer() { [[ "$OPEN_DS_INSTALL_TTY_PATH" != /dev/null ]] && { : <"$OPEN_DS_INSTALL_TTY_PATH"; } 2>/dev/null; }

ask_yes_no() {
  local reply=""
  can_answer || return 1
  printf '%s [y/N] ' "$1" >"$OPEN_DS_INSTALL_TTY_PATH"
  read -r reply <"$OPEN_DS_INSTALL_TTY_PATH" || return 1
  [[ "$reply" =~ ^[Yy]([Ee][Ss])?$ ]]
}

sha256_of() {
  # Hash from stdin: shasum escapes file names containing backslashes and prefixes the hash with "\".
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum <"$1" | awk '{ print $1 }'
  else
    shasum -a 256 <"$1" | awk '{ print $1 }'
  fi
}

# The release file: one Claude Desktop extension for every Mac.
artifact_name() {
  [[ "$(uname -s)" == Darwin ]] || die "This installer is for macOS only (Claude Desktop extensions run on macOS here)"
  printf 'latest.mcpb\n'
}

claude_support_dir() { printf '%s\n' "${HOME%/}/Library/Application Support/Claude"; }

claude_desktop_app() {
  local app
  for app in /Applications/Claude.app "${HOME%/}/Applications/Claude.app"; do
    if [[ -d "$app" ]]; then
      printf '%s\n' "$app"
      return 0
    fi
  done
  return 1
}

# The version of the extension Claude Desktop has installed, or nothing. Its manifest is ours, so the first
# "version" key is the top-level one ("manifest_version" doesn't match: a quote must come right before it).
desktop_version() {
  local manifest
  manifest="$(claude_support_dir)/Claude Extensions/$EXTENSION_ID/manifest.json"
  [[ -f "$manifest" ]] || return 0
  sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$manifest" | head -n 1
}

desktop_enabled() {
  local settings
  settings="$(claude_support_dir)/Claude Extensions Settings/$EXTENSION_ID.json"
  [[ -f "$settings" ]] && grep -Eq '"isEnabled"[[:space:]]*:[[:space:]]*true' "$settings"
}

# The claude command (OPEN_DS_INSTALL_CLAUDE, else claude on PATH), or nothing.
claude_cli() {
  local choice="${OPEN_DS_INSTALL_CLAUDE:-}"
  if [[ "$choice" == none ]]; then return 0; fi
  if [[ -n "$choice" ]]; then
    [[ -x "$choice" ]] && printf '%s\n' "$choice"
    return 0
  fi
  command -v claude 2>/dev/null || true
}

# node, if it's version 20 or later.
node_cli() {
  local node major
  node="$(command -v node 2>/dev/null)" || return 1
  major="$("$node" -p 'process.versions.node.split(".")[0]' 2>/dev/null)" || return 1
  [[ "$major" =~ ^[0-9]+$ && "$major" -ge 20 ]] || return 1
  printf '%s\n' "$node"
}

# What Claude Code has registered as open-ds (its `claude mcp get` output), or nothing.
claude_code_entry() {
  local claude="$1"
  [[ -n "$claude" ]] || return 0
  "$claude" mcp get "$SERVER_NAME" 2>/dev/null || true
}

# Opens the verified bundle with Claude Desktop, which shows its own install dialog (the owner clicks Install).
install_desktop() {
  local bundle="$1" version="$2" have
  have="$(desktop_version)"
  if [[ -n "$version" && "$have" == "$version" ]]; then
    print_success "Claude Desktop already has version $version"
    return 0
  fi
  if ! claude_desktop_app >/dev/null; then
    print_warning "Claude Desktop isn't installed, so the extension wasn't opened. Install it from claude.ai/download and run this again."
    return 0
  fi
  if [[ "${OPEN_DS_INSTALL_NO_OPEN:-}" == "1" ]]; then
    print_step "Not opening Claude Desktop (OPEN_DS_INSTALL_NO_OPEN=1); the extension is in $bundle"
    return 0
  fi
  /usr/bin/open -b "$CLAUDE_BUNDLE_ID" "$bundle" || die "Couldn't open the extension in Claude Desktop: $bundle"
  if [[ -n "$have" ]]; then
    print_success "Claude Desktop is showing the update from $have to ${version:-the latest version}: click Install"
  else
    print_success "Claude Desktop is showing the extension's install dialog: click Install"
  fi
}

# Unpacks the same bundle into <dir>/app/versions/<version>, switches <dir>/app/current to it, and registers it
# with Claude Code at user scope. An open-ds server Claude Code already has elsewhere is replaced only on a yes.
install_claude_code() {
  local bundle="$1" version="$2" dir="$3" default_dir="$4" claude node
  claude="$(claude_cli)"
  if [[ -z "$claude" ]]; then
    print_step "Claude Code isn't installed (no claude command), so only the Claude Desktop extension was set up"
    return 0
  fi
  if ! node="$(node_cli)"; then
    print_warning "Claude Code needs Node.js 20 or later to run this server; install it (brew install node) and run this again"
    return 0
  fi
  local app="$dir/app" target="$dir/app/versions/${version:-unknown}" staging="$OPEN_DS_TEMP_DIR/unpacked"
  mkdir -p "$staging" "$app/versions"
  unzip -q "$bundle" -d "$staging" || die "Couldn't unpack the extension for Claude Code"
  [[ -f "$staging/dist/index.js" ]] || die "The extension doesn't contain dist/index.js"
  rm -rf "$target"
  mv "$staging" "$target"
  ln -sfn "versions/${version:-unknown}" "$app/current.new"
  mv -fh "$app/current.new" "$app/current"
  # Keep the two newest versions, so a broken release can be rolled back by hand.
  local old
  while IFS= read -r old; do
    [[ -n "$old" && "$old" != "${version:-unknown}" ]] && rm -rf "${app:?}/versions/${old:?}"
  done < <(find "$app/versions" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort -t. -k1,1nr -k2,2nr -k3,3nr | tail -n +3)

  local entry="$app/current/dist/index.js" existing
  existing="$(claude_code_entry "$claude")"
  if [[ -n "$existing" ]]; then
    if [[ "$existing" == *"$entry"* ]]; then
      print_success "Claude Code uses it (as $SERVER_NAME)${version:+, now version $version}"
      return 0
    fi
    if ! ask_yes_no "Claude Code already has a server called $SERVER_NAME that runs something else. Replace it?"; then
      print_warning "Left Claude Code's existing $SERVER_NAME server alone. To use this one: claude mcp remove --scope user $SERVER_NAME, then run this again."
      return 0
    fi
    "$claude" mcp remove --scope user "$SERVER_NAME" >/dev/null 2>&1 ||
      die "Couldn't remove Claude Code's existing $SERVER_NAME server (is it in a project's .mcp.json?)"
  fi
  local args=(mcp add --scope user)
  [[ "$dir" == "$default_dir" ]] || args+=(-e "OPEN_DS_MCP_HOME=$dir")
  "$claude" "${args[@]}" "$SERVER_NAME" -- "$node" "$entry" >/dev/null ||
    die "Couldn't add the server to Claude Code (claude mcp add failed)"
  print_success "Added to Claude Code as $SERVER_NAME (start a new session to use it)"
}

# When the WPP sign-in saved in the Keychain expires (seconds since 1970), or nothing if none is saved. The token goes
# only through pipes, never into an argument or the output: just its expiry claim is read.
sign_in_expiry() {
  local payload
  payload="$(/usr/bin/security find-generic-password -s "$KEYCHAIN_SERVICE" -a "storybook:${STORYBOOK#https://}" -w 2>/dev/null |
    cut -d. -f2 | tr '_-' '/+')" || return 0
  [[ -n "$payload" ]] || return 0
  while ((${#payload} % 4)); do payload+="="; done
  printf '%s' "$payload" | base64 -D 2>/dev/null | sed -n 's/.*"exp":\([0-9]*\).*/\1/p'
}

installed_version() {
  local dir="$1"
  [[ -f "$dir/installed.version" ]] && tr -d '[:space:]' <"$dir/installed.version"
}

# The data folder is ours if it carries the marker, or holds what the server itself keeps there.
is_ours() { [[ -e "$1/.open-ds-mcp-home" || -e "$1/settings.json" || -d "$1/cache" ]]; }

print_status() {
  local dir="$1" base="$2" installed latest desktop claude entry expires
  installed="$(installed_version "$dir" || true)"
  latest="$(curl -fsSL "$base/latest.version" 2>/dev/null | tr -d '[:space:]' || true)"
  [[ -n "$latest" ]] || latest="unknown (couldn't reach $base)"
  echo "Open DS MCP Server"
  echo "  Data folder:     $dir$([[ -d "$dir" ]] || echo " (missing)")"
  echo "  Downloaded:      ${installed:-nothing yet}"
  echo "  Latest:          $latest"
  desktop="$(desktop_version)"
  if [[ -n "$desktop" ]]; then
    echo "  Claude Desktop:  version $desktop, $(desktop_enabled && echo enabled || echo "switched off (Settings → Extensions)")"
  else
    echo "  Claude Desktop:  extension not installed"
  fi
  claude="$(claude_cli)"
  if [[ -z "$claude" ]]; then
    echo "  Claude Code:     not installed"
  else
    entry="$(claude_code_entry "$claude")"
    if [[ -z "$entry" ]]; then
      echo "  Claude Code:     no $SERVER_NAME server"
    elif [[ "$entry" == *"$dir/app/current/dist/index.js"* ]]; then
      echo "  Claude Code:     $SERVER_NAME, version $(cd "$dir/app/current" 2>/dev/null && pwd -P | sed 's|.*/||')"
    else
      echo "  Claude Code:     $SERVER_NAME runs something else (not this install)"
    fi
  fi
  expires="$(sign_in_expiry)"
  if [[ -z "$expires" ]]; then
    echo "  WPP sign-in:     not signed in (the first question about Open DS opens it in your browser)"
  elif ((expires > $(date +%s))); then
    echo "  WPP sign-in:     signed in until $(date -r "$expires" '+%a %e %b %H:%M') (kept in your Keychain)"
  else
    echo "  WPP sign-in:     expired (the next question about Open DS opens it in your browser)"
  fi
  if [[ -n "$installed" && "$latest" != unknown* && "$installed" != "$latest" ]]; then
    echo "  Update available: run the install command again, or click Update now on the update card in Claude."
  fi
}

main() {
  [[ -n "${HOME:-}" ]] || die "HOME isn't set, so the installer can't find your home folder"
  local dir="" status_only=false uninstall=false yes=false claude_code=true
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dir)
        [[ $# -ge 2 && -n "$2" ]] || die "--dir needs a folder path"
        dir="$2"
        shift 2
        ;;
      --dir=*)
        dir="${1#--dir=}"
        [[ -n "$dir" ]] || die "--dir needs a folder path"
        shift
        ;;
      --no-claude-code)
        claude_code=false
        shift
        ;;
      --status)
        status_only=true
        shift
        ;;
      --uninstall)
        uninstall=true
        shift
        ;;
      --yes | -y)
        yes=true
        shift
        ;;
      --help | -h)
        usage
        exit 0
        ;;
      *) die "Unknown argument: $1 (try --help)" ;;
    esac
  done

  local default_dir="${HOME%/}/.open-ds-mcp"
  [[ -n "$dir" ]] || dir="${OPEN_DS_MCP_HOME:-$default_dir}"
  # Expand a leading ~ (the shell doesn't when the path arrives quoted or via the environment).
  if [[ "$dir" == \~ || "$dir" == \~/* ]]; then dir="$HOME${dir:1}"; fi
  dir="${dir%/}"
  [[ "$dir" == /* ]] || die "The data folder must be an absolute path: $dir"
  case "/$dir/" in
    */../* | */./*) die "The data folder can't contain . or .. segments: $dir" ;;
  esac
  # Compare physical, lower-cased paths: macOS volumes are case-insensitive by default.
  local canon canon_home p
  canon="$(lowercase "$(canonical_path "$dir")")" || die "Can't resolve the data folder: $dir"
  canon_home="$(lowercase "$(canonical_path "$HOME")")" || die "Can't resolve your home folder"
  [[ "$canon" != "$canon_home" ]] || die "Can't use your home folder itself as the data folder"
  # Your own temporary folder lives under /var on macOS (/var/folders/.../T, where mktemp -d puts things); it
  # isn't a system location.
  local user_tmp
  user_tmp="$(getconf DARWIN_USER_TEMP_DIR 2>/dev/null || true)"
  if [[ -n "$user_tmp" ]]; then user_tmp="$(lowercase "$(canonical_path "${user_tmp%/}")")" || user_tmp=""; fi
  if [[ -z "$user_tmp" || "$user_tmp" == "/" || ("$canon" != "$user_tmp" && "$canon" != "$user_tmp/"*) ]]; then
    for p in "$(claude_support_dir)" /Applications /System /Library /usr /bin /sbin /etc /private/etc /var /opt; do
      [[ -d "$p" ]] || continue
      local canon_p
      canon_p="$(lowercase "$(canonical_path "$p")")"
      if [[ "$canon" == "$canon_p" || "$canon" == "$canon_p/"* ]]; then
        die "Can't use a system or Claude location as the data folder: $dir"
      fi
    done
  fi

  OPEN_DS_INSTALL_TTY_PATH="${OPEN_DS_INSTALL_TTY:-/dev/tty}"
  local base="${OPEN_DS_INSTALL_BASE:-$SITE_BASE_DEFAULT}"
  base="${base%/}"
  # Under curl | bash there is no local install.sh, so the pointers to --status spell out the whole command.
  # Every value is shell-quoted (printf %q) so the printed command can be pasted even when a path holds a
  # space, $, backtick, quote or backslash.
  local q_base q_dir status_cmd
  printf -v q_base '%q' "$base"
  printf -v q_dir '%q' "$dir"
  status_cmd="curl -fsSL $q_base/install.sh | bash -s -- --status"
  [[ "$dir" == "$default_dir" ]] || status_cmd+=" --dir $q_dir"

  if [[ "$status_only" == true ]]; then
    print_status "$dir" "$base"
    return 0
  fi

  if [[ "$uninstall" == true ]]; then
    [[ -d "$dir" ]] || die "Nothing to remove: $dir doesn't exist"
    is_ours "$dir" || die "$dir isn't an Open DS MCP Server data folder; leaving it alone"
    if [[ "$yes" != true ]] && ! ask_yes_no "Remove $dir (the saved extension, cache and chosen release) and Claude Code's $SERVER_NAME entry?"; then
      die "Not removed (with no terminal, add --yes)"
    fi
    local claude entry
    claude="$(claude_cli)"
    entry="$(claude_code_entry "$claude")"
    if [[ -n "$entry" && "$entry" == *"$dir/app/current/dist/index.js"* ]]; then
      if "$claude" mcp remove --scope user "$SERVER_NAME" >/dev/null 2>&1; then
        print_success "Removed $SERVER_NAME from Claude Code"
      else
        print_warning "Couldn't remove $SERVER_NAME from Claude Code; run: claude mcp remove --scope user $SERVER_NAME"
      fi
    fi
    rm -rf "${dir:?}"
    print_success "Removed $dir"
    if [[ -n "$(desktop_version)" ]]; then
      print_step "To remove the Claude Desktop extension: Claude Desktop → Settings → Extensions → Open DS MCP Server → Uninstall"
    fi
    return 0
  fi

  echo ""
  print_step "Installing Open DS MCP Server"
  echo ""

  print_step "Checking prerequisites..."
  local tool
  for tool in curl unzip uname awk sed; do
    command -v "$tool" >/dev/null 2>&1 || die "$tool is not available"
  done
  command -v sha256sum >/dev/null 2>&1 || command -v shasum >/dev/null 2>&1 || die "Neither sha256sum nor shasum is available"
  local artifact
  artifact="$(artifact_name)"
  print_success "macOS ($(uname -m))"

  # The folder must be new, empty, or one of ours.
  if [[ -e "$dir" && ! -d "$dir" ]]; then die "Not a folder: $dir"; fi
  if [[ -d "$dir" ]]; then
    if ! is_ours "$dir" && [[ -n "$(find "$dir" -mindepth 1 -maxdepth 1 ! -name .DS_Store 2>/dev/null)" ]]; then
      die "That folder is not empty and isn't an Open DS MCP Server data folder: $dir"
    fi
    [[ -w "$dir" ]] || die "That folder isn't writable: $dir"
  else
    mkdir -p "$dir" || die "Couldn't create $dir"
    chmod 700 "$dir" || die "Couldn't set permissions on $dir"
  fi
  # Mark the folder as ours straight away, so a re-run after an interruption recognises it.
  touch "$dir/.open-ds-mcp-home"
  print_success "Data folder: $dir"

  # Download into a temp folder and verify before anything is changed.
  OPEN_DS_TEMP_DIR="$(mktemp -d "$dir/.download.XXXXXX")" || die "Couldn't create a temporary folder"
  trap cleanup_temp EXIT

  print_step "Downloading the latest release..."
  curl -fsSL "$base/$artifact" -o "$OPEN_DS_TEMP_DIR/$artifact" || die "Download failed: $base/$artifact"
  curl -fsSL "$base/$artifact.sha256" -o "$OPEN_DS_TEMP_DIR/$artifact.sha256" || die "Download failed: $base/$artifact.sha256"
  local version=""
  if curl -fsSL "$base/latest.version" -o "$OPEN_DS_TEMP_DIR/latest.version" 2>/dev/null; then
    version="$(tr -d '[:space:]' <"$OPEN_DS_TEMP_DIR/latest.version")"
  fi
  [[ -z "$version" || "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]] || die "The site's latest.version isn't a version number"

  local expected actual
  expected="$(awk 'NR == 1 { print tolower($1) }' "$OPEN_DS_TEMP_DIR/$artifact.sha256")"
  actual="$(sha256_of "$OPEN_DS_TEMP_DIR/$artifact")"
  if [[ ! "$expected" =~ ^[0-9a-f]{64}$ || "$expected" != "$actual" ]]; then
    print_error "Checksum mismatch — nothing was installed"
    print_error "Expected: ${expected:-<none>}"
    print_error "Got:      $actual"
    print_error "This can happen for up to about 10 minutes while a new release propagates; wait and run the installer again."
    exit 1
  fi
  print_success "Downloaded and verified${version:+ version $version}"

  local previous
  previous="$(installed_version "$dir" || true)"
  # Claude Code's copy is unpacked from the download before the bundle moves into the data folder.
  if [[ "$claude_code" == true ]]; then
    install_claude_code "$OPEN_DS_TEMP_DIR/$artifact" "$version" "$dir" "$default_dir"
  fi
  mv -f "$OPEN_DS_TEMP_DIR/$artifact" "$dir/$artifact"
  mv -f "$OPEN_DS_TEMP_DIR/$artifact.sha256" "$dir/$artifact.sha256"
  install_desktop "$dir/$artifact" "$version"
  if [[ -n "$version" ]]; then printf '%s\n' "$version" >"$dir/installed.version"; fi
  if [[ -n "$previous" && "$previous" != "$version" ]]; then
    print_success "Updated from $previous to ${version:-the latest version}"
  fi


  echo ""
  print_success "Done. In a new chat, ask Claude: \"Which Open DS component should I use for a date range?\""
  echo "The first question opens a WPP sign-in in your browser. Check the install any time with:"
  echo "  $status_cmd"
}

main "$@"
