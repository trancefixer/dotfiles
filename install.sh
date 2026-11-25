#! /bin/sh
# install.sh - Safe, interactive bootstrapper for trancefixer/dotfiles
# Preserves existing $HOME configs as <file>.local before chezmoi applies changes.
set -eu
if (set -o pipefail 2>/dev/null); then
	set -o pipefail
fi

DOTFILES_REPO="https://github.com/trancefixer/dotfiles.git"
BRANCH="main"
ASSUME_YES=0
DRY_RUN=0
USE_LOCAL_SOURCE=0

usage() {
	cat <<'EOF'
Usage: install.sh [options] [branch]

Safely bootstraps mise + chezmoi, backs up pre-existing conflicting dotfiles in
$HOME to <file>.local, previews pending changes, and applies dotfiles.

Options:
  -b, --branch <name>  Git branch to track when cloning from GitHub (default: main)
  -l, --local          Apply from this script's local repository checkout instead of GitHub
  -n, --dry-run        Initialize source, show backup candidates and chezmoi diff, then exit
  -y, --yes            Non-interactive mode (accept prompts automatically; required if no /dev/tty)
  -h, --help           Show this help message
EOF
}

while [ $# -gt 0 ]; do
	case "$1" in
		-b | --branch)
			[ $# -ge 2 ] || { printf 'Error: %s requires a branch name.\n' "$1" >&2; exit 1; }
			BRANCH="$2"
			shift 2
			;;
		-l | --local)
			USE_LOCAL_SOURCE=1
			shift
			;;
		-n | --dry-run)
			DRY_RUN=1
			shift
			;;
		-y | --yes)
			ASSUME_YES=1
			shift
			;;
		-h | --help)
			usage
			exit 0
			;;
		--)
			shift
			break
			;;
		-*)
			printf 'Error: unknown option: %s\n' "$1" >&2
			usage >&2
			exit 1
			;;
		*)
			BRANCH="$1"
			shift
			;;
	esac
done

# Read interactive confirmation safely from /dev/tty even if script is piped via curl | sh.
confirm() {
	_prompt="$1"
	_default="${2:-y}"

	if [ "$ASSUME_YES" -eq 1 ]; then
		printf '%s [auto-accepted via --yes]\n' "$_prompt"
		return 0
	fi

	if [ ! -r /dev/tty ] || [ ! -w /dev/tty ]; then
		printf 'Error: no interactive terminal (/dev/tty) available to confirm: %s\n' "$_prompt" >&2
		printf 'Re-run in an interactive terminal or pass --yes to proceed non-interactively.\n' >&2
		exit 1
	fi

	if [ "$_default" = "y" ]; then
		_hint="[Y/n]"
	else
		_hint="[y/N]"
	fi

	while :; do
		printf '%s %s ' "$_prompt" "$_hint" > /dev/tty
		if ! IFS= read -r _reply < /dev/tty; then
			printf '\nAborted (EOF on /dev/tty).\n' >&2
			exit 1
		fi
		case "$_reply" in
			"")
				[ "$_default" = "y" ] && return 0 || return 1
				;;
			[Yy] | [Yy][Ee][Ss])
				return 0
				;;
			[Nn] | [Nn][Oo])
				return 1
				;;
			*)
				printf 'Please answer y or n.\n' > /dev/tty
				;;
		esac
	done
}

# Resolve script directory if invoked from a local checkout on disk.
SCRIPT_SOURCE_DIR=""
if [ -f "$0" ]; then
	_candidate_dir="$(CDPATH='' cd -P -- "$(dirname -- "$0")" && pwd -P)"
	if [ -f "$_candidate_dir/.chezmoiroot" ] || [ -d "$_candidate_dir/home" ]; then
		SCRIPT_SOURCE_DIR="$_candidate_dir"
	fi
fi

CHEZMOI_STATE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/chezmoi"
FIRST_RUN=0
if [ ! -d "$CHEZMOI_STATE_DIR/.git" ] && [ "$USE_LOCAL_SOURCE" -eq 0 ]; then
	FIRST_RUN=1
fi

export PATH="$HOME/.local/bin:$PATH"

HAVE_CHEZMOI=0
HAVE_MISE=0
command -v chezmoi >/dev/null 2>&1 && HAVE_CHEZMOI=1
command -v mise >/dev/null 2>&1 && HAVE_MISE=1

# =========================================================================
# First-Run / Interactive Walkthrough Banner
# =========================================================================
printf '\n==> Bootstrapping dotfiles (branch: %s)...\n' "$BRANCH"

if [ "$FIRST_RUN" -eq 1 ]; then
	printf '\nFirst-time setup detected on this host (%s).\n' "${HOSTNAME:-$(hostname 2>/dev/null || printf 'unknown-host')}"
else
	printf '\nExisting chezmoi state or local checkout detected.\n'
fi

if [ "$USE_LOCAL_SOURCE" -eq 0 ] && [ -n "$SCRIPT_SOURCE_DIR" ] && [ "$SCRIPT_SOURCE_DIR" != "$CHEZMOI_STATE_DIR" ]; then
	printf 'Note: You are running install.sh from local checkout: %s\n' "$SCRIPT_SOURCE_DIR"
	if confirm "Use this local checkout as the chezmoi source instead of cloning $DOTFILES_REPO?" "y"; then
		USE_LOCAL_SOURCE=1
	fi
fi

printf '\nHere is what this script will do step by step:\n'
if [ "$HAVE_CHEZMOI" -eq 1 ]; then
	printf '  1. Toolchain : Use existing chezmoi (%s)\n' "$(command -v chezmoi)"
elif [ "$HAVE_MISE" -eq 1 ]; then
	printf '  1. Toolchain : Use existing mise (%s) to install chezmoi@latest\n' "$(command -v mise)"
else
	printf '  1. Toolchain : Download https://mise.run to a temporary file, install mise to\n'
	printf '                 ~/.local/bin/mise, then install chezmoi@latest\n'
fi

if [ "$USE_LOCAL_SOURCE" -eq 1 ]; then
	if [ -z "$SCRIPT_SOURCE_DIR" ]; then
		printf 'Error: --local specified, but install.sh is not inside a dotfiles checkout.\n' >&2
		exit 1
	fi
	SOURCE_DIR="$SCRIPT_SOURCE_DIR"
	printf '  2. Source    : Read dotfiles directly from local checkout (%s)\n' "$SOURCE_DIR"
else
	SOURCE_DIR="$CHEZMOI_STATE_DIR"
	printf '  2. Source    : Clone/update %s (branch: %s) into %s\n' "$DOTFILES_REPO" "$BRANCH" "$SOURCE_DIR"
	printf '                 WITHOUT touching $HOME yet\n'
fi

printf '  3. Backup    : Back up any pre-existing differing $HOME files (and legacy\n'
printf '                 .chezmoiremove targets like ~/.gitconfig) to <file>.local\n'
printf '                 (never overwriting an existing <file>.local)\n'
printf '  4. Preview   : Show a diff summary of changes chezmoi wants to make in $HOME\n'
if [ "$DRY_RUN" -eq 1 ]; then
	printf '  5. Apply     : SKIPPED (--dry-run enabled)\n\n'
else
	printf '  5. Apply     : Ask for final confirmation before applying dotfiles to $HOME\n\n'
fi

if ! confirm "Proceed with Step 1 & Step 2 (prepare toolchain and dotfiles source)?" "y"; then
	printf 'Aborted before making any changes.\n'
	exit 0
fi

# =========================================================================
# Step 1: Ensure chezmoi is available (install mise safely if needed)
# =========================================================================
TMP_INSTALLER=""
cleanup() {
	if [ -n "$TMP_INSTALLER" ] && [ -e "$TMP_INSTALLER" ]; then
		rm -f "$TMP_INSTALLER"
	fi
}
trap cleanup EXIT INT TERM

run_chezmoi() {
	if [ "$HAVE_CHEZMOI" -eq 1 ]; then
		chezmoi "$@"
	else
		mise exec chezmoi@latest -- chezmoi "$@"
	fi
}

if [ "$HAVE_CHEZMOI" -eq 0 ]; then
	# 1. Install mise if missing (mise.run installs to ~/.local/bin/mise)
	if [ "$HAVE_MISE" -eq 0 ]; then
		printf '\n==> Step 1a: Downloading mise installer from https://mise.run ...\n'
		TMP_INSTALLER="$(mktemp "${TMPDIR%/}/mise-install.XXXXXX" 2>/dev/null || mktemp /tmp/mise-install.XXXXXX)"
		if command -v curl >/dev/null 2>&1; then
			curl -fsSL https://mise.run -o "$TMP_INSTALLER"
		elif command -v wget >/dev/null 2>&1; then
			wget -qO "$TMP_INSTALLER" https://mise.run
		else
			printf 'Error: neither curl nor wget is installed.\n' >&2
			exit 1
		fi

		if [ ! -s "$TMP_INSTALLER" ]; then
			printf 'Error: downloaded mise installer is empty.\n' >&2
			exit 1
		fi

		if ! confirm "Run downloaded mise installer ($TMP_INSTALLER) to install ~/.local/bin/mise?" "y"; then
			printf 'Aborted before running mise installer.\n'
			exit 0
		fi
		sh "$TMP_INSTALLER" < /dev/null
	fi

	printf '==> Step 1b: Installing chezmoi@latest via mise...\n'
	mise use --global chezmoi@latest < /dev/null
	if command -v chezmoi >/dev/null 2>&1; then
		HAVE_CHEZMOI=1
	fi
fi

# =========================================================================
# Step 2: Initialize or update chezmoi source WITHOUT applying yet
# =========================================================================
if [ "$USE_LOCAL_SOURCE" -eq 0 ]; then
	printf '\n==> Step 2: Fetching dotfiles source (%s, branch: %s)...\n' "$DOTFILES_REPO" "$BRANCH"
	if [ -d "$CHEZMOI_STATE_DIR/.git" ]; then
		git -C "$CHEZMOI_STATE_DIR" fetch --prune origin < /dev/null
		git -C "$CHEZMOI_STATE_DIR" switch "$BRANCH" < /dev/null
		git -C "$CHEZMOI_STATE_DIR" pull --ff-only origin "$BRANCH" < /dev/null
	else
		run_chezmoi init --branch "$BRANCH" "$DOTFILES_REPO" < /dev/null
	fi
fi

# =========================================================================
# Step 3: Guard - Back up pre-existing differing/removed files to <file>.local
# =========================================================================
backup_one_path() {
	_target="$1"
	_mode="$2" # "copy" for managed files, "move" for .chezmoiremove legacy files
	_ts="$3"

	_backup="${_target}.local"
	if [ -e "$_backup" ] || [ -L "$_backup" ]; then
		_backup="${_target}.local.${_ts}"
	fi

	if [ "$DRY_RUN" -eq 1 ]; then
		printf '  [dry-run] Would back up %s -> %s (%s)\n' "$_target" "$_backup" "$_mode"
		return 0
	fi

	mkdir -p "$(dirname -- "$_backup")"
	if [ "$_mode" = "move" ]; then
		mv "$_target" "$_backup"
		printf '  Rescued legacy file %s -> %s\n' "$_target" "$_backup"
	else
		cp -Pp "$_target" "$_backup"
		printf '  Backed up existing %s -> %s\n' "$_target" "$_backup"
	fi
}

backup_existing_dotfiles() {
	_src="$1"
	_dest="$2"
	_ts="$(date -u +%Y%m%d-%H%M%S)"
	_found=0

	printf '\n==> Step 3: Scanning $HOME for pre-existing dotfiles to preserve as <file>.local ...\n'

	# 3a. Managed files/symlinks that already exist in $HOME and differ from rendered target
	_managed_list="$(mktemp "${TMPDIR%/}/chezmoi-managed.XXXXXX" 2>/dev/null || mktemp /tmp/chezmoi-managed.XXXXXX)"
	run_chezmoi managed --source "$_src" --destination "$_dest" --include=files,symlinks < /dev/null > "$_managed_list"

	while IFS= read -r _rel || [ -n "$_rel" ]; do
		[ -n "$_rel" ] || continue
		_target="$_dest/$_rel"

		if [ ! -e "$_target" ] && [ ! -L "$_target" ]; then
			continue
		fi

		# Skip if regular file on disk already matches chezmoi's rendered output byte-for-byte
		if [ -f "$_target" ] && [ ! -L "$_target" ]; then
			if run_chezmoi cat --source "$_src" --destination "$_dest" "$_target" < /dev/null 2>/dev/null | cmp -s - "$_target"; then
				continue
			fi
		fi

		_found=1
		backup_one_path "$_target" "copy" "$_ts"
	done < "$_managed_list"
	rm -f "$_managed_list"

	# 3b. Legacy files listed in .chezmoiremove before chezmoi deletes them
	_remove_manifest="$_src/home/.chezmoiremove"
	[ -f "$_src/.chezmoiroot" ] || _remove_manifest="$_src/.chezmoiremove"

	if [ -r "$_remove_manifest" ]; then
		while IFS= read -r _rem || [ -n "$_rem" ]; do
			case "$_rem" in
				"" | "#"*) continue ;;
			esac
			_target="$_dest/$_rem"
			if [ -e "$_target" ] || [ -L "$_target" ]; then
				_found=1
				backup_one_path "$_target" "move" "$_ts"
			fi
		done < "$_remove_manifest"
	fi

	if [ "$_found" -eq 0 ]; then
		printf '  No conflicting pre-existing dotfiles found (everything is clean or already matches).\n'
	fi
}

backup_existing_dotfiles "$SOURCE_DIR" "$HOME"

# =========================================================================
# Step 4 & Step 5: Preview Diff & Confirm Apply
# =========================================================================
printf '\n==> Step 4: Previewing pending chezmoi changes against %s ...\n' "$HOME"
DIFF_FILE="$(mktemp "${TMPDIR%/}/chezmoi-diff.XXXXXX" 2>/dev/null || mktemp /tmp/chezmoi-diff.XXXXXX)"
run_chezmoi diff --source "$SOURCE_DIR" --destination "$HOME" < /dev/null > "$DIFF_FILE" || true

if [ ! -s "$DIFF_FILE" ]; then
	rm -f "$DIFF_FILE"
	printf '==> $HOME already matches dotfiles source; nothing to apply.\n'
	printf '==> Setup complete!\n'
	exit 0
fi

_diff_lines="$(wc -l < "$DIFF_FILE" | tr -d ' ')"
printf 'Pending diff spans %s lines.\n' "$_diff_lines"
if [ "$ASSUME_YES" -eq 0 ] && confirm "View full chezmoi diff before applying?" "y"; then
	if [ "$_diff_lines" -gt 40 ] && command -v less >/dev/null 2>&1 && [ -r /dev/tty ]; then
		less -FRX "$DIFF_FILE" < /dev/tty > /dev/tty
	else
		cat "$DIFF_FILE"
	fi
fi
rm -f "$DIFF_FILE"

if [ "$DRY_RUN" -eq 1 ]; then
	printf '\n==> Dry-run complete (no files in $HOME were modified).\n'
	exit 0
fi

if ! confirm "Apply these dotfiles changes to $HOME now?" "y"; then
	printf 'Skipped chezmoi apply. Your backups (if any) remain intact.\n'
	exit 0
fi

# 2. Install chezmoi via mise and apply dotfiles
printf '\n==> Step 5: Applying dotfiles to %s ...\n' "$HOME"
run_chezmoi apply --source "$SOURCE_DIR" --destination "$HOME" < /dev/null

printf '==> Setup complete!\n'