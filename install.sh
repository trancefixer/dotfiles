#! /bin/sh
# install.sh - Safe, interactive bootstrapper for trancefixer/dotfiles
# Detects existing chezmoistate.boltdb / local repo checkouts and lets the user
# control or skip <file>.local backups interactively or via flags.
set -eu
if (set -o pipefail 2>/dev/null); then
	set -o pipefail
fi

DOTFILES_REPO="https://github.com/trancefixer/dotfiles.git"
BRANCH="main"
ASSUME_YES=0
DRY_RUN=0
SOURCE_MODE="auto"     # auto | local | remote | custom
CUSTOM_SOURCE_DIR=""
BACKUP_MODE="ask"      # ask | all | none | each
BACKUP_SUFFIX=".local"

usage() {
	cat <<'EOF'
Usage: install.sh [options] [branch]

Safely bootstraps mise + chezmoi, previews differing files with optional
<file>.local backups, shows chezmoi diff, and applies dotfiles.

Options:
  -s, --source <dir>         Use explicit chezmoi source directory
  -l, --local                Force using this script's local checkout as source
  -r, --remote               Clone/update GitHub repo into ~/.local/share/chezmoi
  -b, --branch <name>        Git branch when using --remote (default: main)
      --backup               Back up all differing files without asking
      --no-backup            Skip backing up differing/removed files completely
      --backup-each          Prompt file-by-file for backups
      --backup-suffix <ext>  Suffix for backups (default: .local)
  -n, --dry-run              Preview backup candidates and chezmoi diff, then exit
  -y, --yes                  Non-interactive mode (implies --backup unless --no-backup set)
  -h, --help                 Show this help message
EOF
}

while [ $# -gt 0 ]; do
	case "$1" in
		-s | --source)
			[ $# -ge 2 ] || { printf 'Error: %s requires a directory.\n' "$1" >&2; exit 1; }
			SOURCE_MODE="custom"
			CUSTOM_SOURCE_DIR="$2"
			shift 2
			;;
		-l | --local)
			SOURCE_MODE="local"
			shift
			;;
		-r | --remote)
			SOURCE_MODE="remote"
			shift
			;;
		-b | --branch)
			[ $# -ge 2 ] || { printf 'Error: %s requires a branch name.\n' "$1" >&2; exit 1; }
			BRANCH="$2"
			shift 2
			;;
		--backup)
			BACKUP_MODE="all"
			shift
			;;
		--no-backup)
			BACKUP_MODE="none"
			shift
			;;
		--backup-each)
			BACKUP_MODE="each"
			shift
			;;
		--backup-suffix)
			[ $# -ge 2 ] || { printf 'Error: %s requires a suffix (e.g. .bak).\n' "$1" >&2; exit 1; }
			BACKUP_SUFFIX="$2"
			shift 2
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

if [ "$ASSUME_YES" -eq 1 ] && [ "$BACKUP_MODE" = "ask" ]; then
	BACKUP_MODE="all"
fi

# Read yes/no confirmation safely from /dev/tty even when piped via curl | sh.
confirm() {
	_prompt="$1"
	_default="${2:-y}"

	if [ "$ASSUME_YES" -eq 1 ]; then
		printf '%s [auto-accepted via --yes]\n' "$_prompt"
		return 0
	fi

	if [ ! -r /dev/tty ] || [ ! -w /dev/tty ]; then
		printf 'Error: no interactive /dev/tty to confirm: %s\n' "$_prompt" >&2
		printf 'Re-run in a terminal or pass --yes (and --no-backup if desired).\n' >&2
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
			[Yy] | [Yy][Ee][Ss]) return 0 ;;
			[Nn] | [Nn][Oo]) return 1 ;;
			*) printf 'Please answer y or n.\n' > /dev/tty ;;
		esac
	done
}

# Detect if install.sh resides inside a local dotfiles checkout.
SCRIPT_SOURCE_DIR=""
if [ -f "$0" ]; then
	_cand="$(CDPATH='' cd -P -- "$(dirname -- "$0")" && pwd -P)"
	if [ -f "$_cand/.chezmoiroot" ] || [ -d "$_cand/home" ]; then
		SCRIPT_SOURCE_DIR="$_cand"
	fi
fi

CHEZMOI_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/chezmoi"
CHEZMOI_BOLTDB="$CHEZMOI_CONFIG_DIR/chezmoistate.boltdb"
CHEZMOI_CONFIG_TOML="$CHEZMOI_CONFIG_DIR/chezmoi.toml"
CHEZMOI_DEFAULT_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/chezmoi"

# Detect whether chezmoi has ever run on this host (via boltdb state or data dir).
FIRST_RUN=1
if [ -f "$CHEZMOI_BOLTDB" ] || [ -d "$CHEZMOI_DEFAULT_DATA_DIR/.git" ]; then
	FIRST_RUN=0
fi

# Resolve SOURCE_DIR based on mode and local checkout presence.
case "$SOURCE_MODE" in
	custom)
		SOURCE_DIR="$(CDPATH='' cd -P -- "$CUSTOM_SOURCE_DIR" && pwd -P)"
		;;
	local)
		if [ -z "$SCRIPT_SOURCE_DIR" ]; then
			printf 'Error: --local specified, but install.sh is not inside a dotfiles checkout.\n' >&2
			exit 1
		fi
		SOURCE_DIR="$SCRIPT_SOURCE_DIR"
		;;
	remote)
		SOURCE_DIR="$CHEZMOI_DEFAULT_DATA_DIR"
		;;
	auto)
		if [ -n "$SCRIPT_SOURCE_DIR" ]; then
			SOURCE_DIR="$SCRIPT_SOURCE_DIR"
			SOURCE_MODE="local"
		else
			SOURCE_DIR="$CHEZMOI_DEFAULT_DATA_DIR"
			SOURCE_MODE="remote"
		fi
		;;
esac

export PATH="$HOME/.local/bin:$PATH"

HAVE_CHEZMOI=0
HAVE_MISE=0
command -v chezmoi >/dev/null 2>&1 && HAVE_CHEZMOI=1
command -v mise >/dev/null 2>&1 && HAVE_MISE=1

# =========================================================================
# Interactive Status & Execution Plan Banner
# =========================================================================
_host="${HOSTNAME:-$(hostname 2>/dev/null || printf 'unknown-host')}"
printf '\n==> Dotfiles Bootstrapper (%s)\n' "$_host"

if [ "$FIRST_RUN" -eq 1 ]; then
	printf 'Status : First-time chezmoi run on this host (no chezmoistate.boltdb found).\n'
else
	printf 'Status : Previous chezmoi state detected (%s).\n' "$CHEZMOI_BOLTDB"
fi

printf '\nExecution Plan:\n'
if [ "$HAVE_CHEZMOI" -eq 1 ]; then
	printf '  1. Toolchain : Use installed chezmoi (%s)\n' "$(command -v chezmoi)"
elif [ "$HAVE_MISE" -eq 1 ]; then
	printf '  1. Toolchain : Install chezmoi@latest via existing mise (%s)\n' "$(command -v mise)"
else
	printf '  1. Toolchain : Download https://mise.run to temp file -> install mise -> install chezmoi@latest\n'
fi

if [ "$SOURCE_MODE" = "remote" ]; then
	printf '  2. Source    : Clone/update %s (branch: %s) -> %s\n' "$DOTFILES_REPO" "$BRANCH" "$SOURCE_DIR"
else
	printf '  2. Source    : Use local checkout directly (%s)\n' "$SOURCE_DIR"
	printf '                 (pass --remote if you want ~/.local/share/chezmoi cloned instead)\n'
fi

case "$BACKUP_MODE" in
	none) printf '  3. Backup    : DISABLED (--no-backup)\n' ;;
	all)  printf '  3. Backup    : Auto-backup differing/removed files to *%s\n' "$BACKUP_SUFFIX" ;;
	each) printf '  3. Backup    : Prompt file-by-file for *%s backups\n' "$BACKUP_SUFFIX" ;;
	ask)  printf '  3. Backup    : Scan for differing files, then ask whether to back up (*%s) or skip\n' "$BACKUP_SUFFIX" ;;
esac

printf '  4. Preview   : Show chezmoi diff against %s\n' "$HOME"
if [ "$DRY_RUN" -eq 1 ]; then
	printf '  5. Apply     : SKIPPED (--dry-run enabled)\n\n'
else
	printf '  5. Apply     : Prompt before applying changes to %s\n\n' "$HOME"
fi

if [ "$FIRST_RUN" -eq 1 ]; then
	if ! confirm "Continue with first-time setup plan above?" "y"; then
		printf 'Aborted.\n'
		exit 0
	fi
fi

# =========================================================================
# Step 1: Ensure chezmoi is available (install mise safely if needed)
# =========================================================================
TMP_FILES=""
register_tmp() {
	TMP_FILES="$TMP_FILES $1"
}
cleanup() {
	for _f in $TMP_FILES; do
		[ -n "$_f" ] && [ -e "$_f" ] && rm -f "$_f"
	done
}
trap cleanup EXIT INT TERM

make_tmp() {
	_t="$(mktemp "${TMPDIR%/}/dotfiles-install.XXXXXX" 2>/dev/null || mktemp /tmp/dotfiles-install.XXXXXX)"
	register_tmp "$_t"
	printf '%s\n' "$_t"
}

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
		TMP_INSTALLER="$(make_tmp)"
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
	command -v chezmoi >/dev/null 2>&1 && HAVE_CHEZMOI=1
fi

# =========================================================================
# Step 2: Prepare dotfiles source (and optionally pin sourceDir in chezmoi.toml)
# =========================================================================
if [ "$SOURCE_MODE" = "remote" ]; then
	printf '\n==> Step 2: Fetching remote dotfiles (%s, branch: %s)...\n' "$DOTFILES_REPO" "$BRANCH"
	if [ -d "$SOURCE_DIR/.git" ]; then
		git -C "$SOURCE_DIR" fetch --prune origin < /dev/null
		git -C "$SOURCE_DIR" switch "$BRANCH" < /dev/null
		git -C "$SOURCE_DIR" pull --ff-only origin "$BRANCH" < /dev/null
	else
		run_chezmoi init --branch "$BRANCH" "$DOTFILES_REPO" < /dev/null
	fi
else
	# Offer to configure ~/.config/chezmoi/chezmoi.toml sourceDir if missing so plain `chezmoi` works anywhere
	if [ ! -f "$CHEZMOI_CONFIG_TOML" ] && [ "$DRY_RUN" -eq 0 ]; then
		if confirm "Point $CHEZMOI_CONFIG_TOML sourceDir to $SOURCE_DIR so plain 'chezmoi diff/apply' works without --source?" "y"; then
			mkdir -p "$CHEZMOI_CONFIG_DIR"
			printf 'sourceDir = "%s"\n' "$SOURCE_DIR" > "$CHEZMOI_CONFIG_TOML"
			chmod 600 "$CHEZMOI_CONFIG_TOML"
			printf 'Wrote %s\n' "$CHEZMOI_CONFIG_TOML"
		fi
	fi
fi

# =========================================================================
# Step 3: Optional Backup of Differing / Legacy Files (User-Overridable)
# =========================================================================
backup_one_path() {
	_target="$1"
	_action="$2" # copy | move
	_ts="$3"

	_backup="${_target}${BACKUP_SUFFIX}"
	if [ -e "$_backup" ] || [ -L "$_backup" ]; then
		_backup="${_target}${BACKUP_SUFFIX}.${_ts}"
	fi

	if [ "$DRY_RUN" -eq 1 ]; then
		printf '  [dry-run] Would %s %s -> %s\n' "$_action" "$_target" "$_backup"
		return 0
	fi

	mkdir -p "$(dirname -- "$_backup")"
	if [ "$_action" = "move" ]; then
		mv "$_target" "$_backup"
		printf '  Rescued legacy %s -> %s\n' "$_target" "$_backup"
	else
		cp -Pp "$_target" "$_backup"
		printf '  Backed up %s -> %s\n' "$_target" "$_backup"
	fi
}

prompt_backup_policy() {
	if [ ! -r /dev/tty ] || [ ! -w /dev/tty ]; then
		printf 'No /dev/tty available; defaulting to backing up all listed files.\n'
		BACKUP_MODE="all"
		return 0
	fi

	while :; do
		printf 'Backup action: [a]ll to *%s, [s]kip backups, [i]ndividual prompt, [q]uit? [a/s/i/q] (default: s): ' "$BACKUP_SUFFIX" > /dev/tty
		if ! IFS= read -r _choice < /dev/tty; then
			exit 1
		fi
		case "$_choice" in
			"" | [Ss] | [Ss][Kk][Ii][Pp])
				BACKUP_MODE="none"
				return 0
				;;
			[Aa] | [Aa][Ll][Ll])
				BACKUP_MODE="all"
				return 0
				;;
			[Ii] | [Ee])
				BACKUP_MODE="each"
				return 0
				;;
			[Qq] | [Qq][Uu][Ii][Tt])
				printf 'Aborted.\n'
				exit 0
				;;
			*)
				printf 'Please enter a (all), s (skip), i (individual), or q (quit).\n' > /dev/tty
				;;
		esac
	done
}

handle_backups() {
	_src="$1"
	_dest="$2"

	if [ "$BACKUP_MODE" = "none" ]; then
		printf '\n==> Step 3: Skipping backups (--no-backup).\n'
		return 0
	fi

	printf '\n==> Step 3: Checking %s for existing files that differ from %s ...\n' "$_dest" "$_src"
	_candidates="$(make_tmp)"
	_managed="$(make_tmp)"

	run_chezmoi managed --source "$_src" --destination "$_dest" --include=files,symlinks < /dev/null > "$_managed"

	while IFS= read -r _rel || [ -n "$_rel" ]; do
		[ -n "$_rel" ] || continue
		_target="$_dest/$_rel"
		if [ ! -e "$_target" ] && [ ! -L "$_target" ]; then
			continue
		fi
		if [ -f "$_target" ] && [ ! -L "$_target" ]; then
			if run_chezmoi cat --source "$_src" --destination "$_dest" "$_target" < /dev/null 2>/dev/null | cmp -s - "$_target"; then
				continue
			fi
		fi
		printf 'copy\t%s\n' "$_target" >> "$_candidates"
	done < "$_managed"

	_remove_manifest="$_src/home/.chezmoiremove"
	[ -f "$_src/.chezmoiroot" ] || _remove_manifest="$_src/.chezmoiremove"
	if [ -r "$_remove_manifest" ]; then
		while IFS= read -r _rem || [ -n "$_rem" ]; do
			case "$_rem" in
				"" | "#"*) continue ;;
			esac
			_target="$_dest/$_rem"
			if [ -e "$_target" ] || [ -L "$_target" ]; then
				printf 'move\t%s\n' "$_target" >> "$_candidates"
			fi
		done < "$_remove_manifest"
	fi

	if [ ! -s "$_candidates" ]; then
		printf '  All existing files already match chezmoi source (nothing needs backup).\n'
		return 0
	fi

	printf '  Found differing/legacy files in %s:\n' "$_dest"
	while IFS="$(printf '\t')" read -r _act _path; do
		if [ "$_act" = "move" ]; then
			printf '    - %s (queued for removal in .chezmoiremove)\n' "$_path"
		else
			printf '    - %s (differs from source)\n' "$_path"
		fi
	done < "$_candidates"

	if [ "$BACKUP_MODE" = "ask" ]; then
		# Default to 's' (skip) on hosts with prior chezmoi history, 'a' (all) on brand-new hosts
		if [ "$FIRST_RUN" -eq 1 ]; then
			printf '  Tip: First run on this host - choosing [a] preserves originals as *%s.\n' "$BACKUP_SUFFIX"
		else
			printf '  Tip: Host already uses chezmoi - press Enter ([s]) to skip cluttering $HOME with *%s backups.\n' "$BACKUP_SUFFIX"
		fi
		prompt_backup_policy
	fi

	if [ "$BACKUP_MODE" = "none" ]; then
		printf '  Skipping backups per user selection.\n'
		return 0
	fi

	_ts="$(date -u +%Y%m%d-%H%M%S)"
	while IFS="$(printf '\t')" read -r _act _path; do
		if [ "$BACKUP_MODE" = "each" ]; then
			if ! confirm "  Back up $_path -> ${_path}${BACKUP_SUFFIX}?" "n"; then
				continue
			fi
		fi
		backup_one_path "$_path" "$_act" "$_ts"
	done < "$_candidates"
}

handle_backups "$SOURCE_DIR" "$HOME"

# =========================================================================
# Step 4 & Step 5: Preview Diff & Confirm Apply
# =========================================================================
printf '\n==> Step 4: Computing chezmoi diff against %s ...\n' "$HOME"
DIFF_FILE="$(make_tmp)"
run_chezmoi diff --source "$SOURCE_DIR" --destination "$HOME" < /dev/null > "$DIFF_FILE" || true

if [ ! -s "$DIFF_FILE" ]; then
	printf '==> %s already matches %s; nothing to apply.\n' "$HOME" "$SOURCE_DIR"
	printf '==> Setup complete!\n'
	exit 0
fi

_diff_lines="$(wc -l < "$DIFF_FILE" | tr -d ' ')"
printf 'Pending diff spans %s lines.\n' "$_diff_lines"
if [ "$ASSUME_YES" -eq 0 ] && confirm "Inspect full chezmoi diff before applying?" "y"; then
	if [ "$_diff_lines" -gt 40 ] && command -v less >/dev/null 2>&1 && [ -r /dev/tty ]; then
		less -FRX "$DIFF_FILE" < /dev/tty > /dev/tty
	else
		cat "$DIFF_FILE"
	fi
fi

if [ "$DRY_RUN" -eq 1 ]; then
	printf '\n==> Dry-run complete (no files in %s were modified).\n' "$HOME"
	exit 0
fi

if ! confirm "Apply these chezmoi changes to $HOME now?" "y"; then
	printf 'Skipped chezmoi apply.\n'
	exit 0
fi

# 2. Install chezmoi via mise and apply dotfiles
printf '\n==> Step 5: Applying dotfiles from %s to %s ...\n' "$SOURCE_DIR" "$HOME"
run_chezmoi apply --source "$SOURCE_DIR" --destination "$HOME" < /dev/null

printf '==> Setup complete!\n'