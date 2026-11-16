#!/bin/sh
SUMMARY=''
NOW=$(date +"%Y-%m-%d-%R")
DIR=~/curatescape_utility
PLUGINS_DIR=~/curatescape_utility/plugins
THEMES_DIR=~/curatescape_utility/themes
LOCAL_PLUGINS=''
LOCAL_THEMES=''
PLUGIN_SOURCES=()
THEME_SOURCES=()
SCRIPT_LOCATION=$(pwd)
ME="${0##*/}"

RED='\E[0;31m'
GREEN='\E[0;32m'
YELLOW='\E[0;33m'
CYAN='\E[0;36m'
NOCOLOR='\E[0m'
BOLD=$(tput bold)
NORMAL=$(tput sgr0)

GITHUB_REPOS_PLUGINS=(
	CPHDH/Curatescape
	CPHDH/CuratescapeSeo
	CPHDH/CuratescapeGalleries
	omeka/plugin-Geolocation
	omeka/plugin-SimplePages
	omeka/plugin-SimpleVocab
	ebellempire/MoreUserRoles
	ebellempire/SubjectsBrowse
)

# Theme directory structure is automatically detected using theme.ini
GITHUB_REPOS_THEMES=(
	CPHDH/theme-curatescape
	CPHDH/theme-curatescape-echo
)

usage() {
	echo -e "Include at least one path to an existing Omeka installation. Here's an example: \n${YELLOW}bash ${ME} path/to/omeka1 path/to/omeka2${NOCOLOR}"
	echo -e "Options (before the paths; each takes its value after = or a space):
  --localplugins DIR   install every plugin folder in DIR instead of downloading the listed plugins from GitHub
  --localthemes DIR    install every theme folder in DIR instead of downloading the listed themes from GitHub
  -h, --help           show this help
For servers that block outgoing requests, upload the new plugin and theme versions to their own separate folders and point the script at them:
${YELLOW}bash ${ME} --localplugins=path/to/plugins --localthemes=path/to/themes path/to/omeka${NOCOLOR}"
}

fatal() {
	echo -e "${RED}█ ERROR: $1${NOCOLOR}"
	exit 1
}

# Get the latest GitHub release tag
get_latest_release() {
	curl --silent "https://api.github.com/repos/$1/releases/latest" |
	grep '"tag_name":' |
	sed -E 's/.*"([^"]+)".*/\1/'
}

# Resolve a ref to checkout: "latest" fetches the latest release, otherwise use as-is
# Supports: owner/repo@latest, owner/repo@1.0, owner/repo@master, or owner/repo (defaults to latest)
resolve_ref() {
	local REPO=$1
	local REF=$2
	if [ -z "$REF" ] || [ "$REF" = "latest" ]; then
		get_latest_release "$REPO"
	else
		echo "$REF"
	fi
}

# Clone a repo shallowly and handle failure by cleaning up the partial directory
# Passes --branch if a non-"latest" ref is known, to minimize data fetched
clone_repo() {
	local REPO_NAME=$1
	local DEST=$2
	local REF=$3
	local BRANCH_ARG=""
	if [ -n "$REF" ] && [ "$REF" != "latest" ]; then
		BRANCH_ARG="--branch $REF"
	fi
	if ! git clone --depth 1 $BRANCH_ARG "https://github.com/${REPO_NAME}.git" "$DEST"; then
		echo -e "${RED}█ ERROR: Failed to clone '${REPO_NAME}'. Cleaning up and skipping.${NOCOLOR}"
		rm -rf "$DEST"
		return 1
	fi
	return 0
}

# Get the folder a repo goes in, minus the owner, the @ref and the given prefix (omeka/plugin-Geolocation@master with plugin- is Geolocation)
repo_folder() {
	local NAME=${1%@*}
	NAME=${NAME#*/}
	echo "${NAME#"$2"}"
}

# repo_note COLOR REPO_NAME MESSAGE: prints MESSAGE and adds it to the summary under REPO_NAME
repo_note() {
	echo -e "${1}█ ${2}: ${3}${NOCOLOR}"
	SUMMARY+="\n${1}${BOLD}✗ ${2}:${NORMAL}${NOCOLOR}\n  ➡ ${3}\n"${NOCOLOR}
}

# get_repo REPO_SPEC PARENT PREFIX: clones or updates owner/repo[@ref] in PARENT (in a folder named without the owner or PREFIX) and checks out the ref: a branch, a tag, or the latest release when there's no @ref
get_repo() {
	local SPEC=$1 PARENT=$2 PREFIX=$3 REPO_NAME REPO_REF DEST CHECKOUT_REF
	### parse "owner/repo@ref" or "owner/repo"
	case $SPEC in
		*@*) REPO_NAME=${SPEC%@*}; REPO_REF=${SPEC#*@} ;;
		*) REPO_NAME=$SPEC; REPO_REF=latest ;;
	esac
	DEST="${PARENT}/$(repo_folder "$REPO_NAME" "$PREFIX")"
	CHECKOUT_REF=$(resolve_ref "$REPO_NAME" "$REPO_REF")
	if [ ! -d "$DEST" ]; then
		echo -e ${CYAN}"█ Cloning '${REPO_NAME}'..." ${NOCOLOR}
		if ! clone_repo "$REPO_NAME" "$DEST" "$REPO_REF"; then
			SUMMARY+="\n${RED}${BOLD}✗ ${REPO_NAME}:${NORMAL}${NOCOLOR}\n  ➡ Clone failed (see above for details)\n"${NOCOLOR}
			return 1
		fi
		if [ -z "$CHECKOUT_REF" ]; then
			repo_note "$YELLOW" "$REPO_NAME" "No release found (it may not have any, or GitHub's API may be limiting requests); using its default branch"
			return 0
		fi
		echo -e ${CYAN}"Checking out '${CHECKOUT_REF}' for ${REPO_NAME}\n" ${NOCOLOR}
		# A branch or tag given with @ref was cloned directly. For the latest release, the shallow clone only has the default branch's newest commit, so the release tag is fetched on its own (cloning at the tag instead would leave a clone that can't fetch branches if the @ref changes later)
		if [ "$REPO_REF" = latest ]; then
			if ! git -C "$DEST" fetch -q --depth 1 origin tag "$CHECKOUT_REF" || ! git -C "$DEST" checkout -q "$CHECKOUT_REF"; then
				rm -rf "$DEST"
				repo_note "$RED" "$REPO_NAME" "Couldn't check out release '${CHECKOUT_REF}', so it was skipped (see above for details)"
				return 1
			fi
		fi
	else
		echo -e ${CYAN}"█ The git repo '${REPO_NAME}' already exists; checking for updates ..." ${NOCOLOR}
		git -C "$DEST" fetch --depth 1 --tags origin
		if [ -z "$CHECKOUT_REF" ]; then
			repo_note "$YELLOW" "$REPO_NAME" "No release found (it may not have any, or GitHub's API may be limiting requests); kept the copy from the last run"
			return 0
		fi
		echo -e ${CYAN}"Checking out '${CHECKOUT_REF}' for ${REPO_NAME}\n" ${NOCOLOR}
		if ! git -C "$DEST" checkout -q "$CHECKOUT_REF"; then
			repo_note "$YELLOW" "$REPO_NAME" "Couldn't check out '${CHECKOUT_REF}'; kept the copy from the last run (see above for details)"
			return 0
		fi
		if git -C "$DEST" symbolic-ref -q HEAD > /dev/null 2>&1; then git -C "$DEST" reset -q --hard FETCH_HEAD; fi
	fi
}

# Get theme structure using location of theme.ini
find_theme_dir() {
	local REPO_PATH=$1

	# Check if theme.ini exists in the root
	if [ -f "${REPO_PATH}/theme.ini" ]; then
		echo "${REPO_PATH}"
		return
	fi

	# Check subdirectories for theme.ini
	for SUBDIR in "${REPO_PATH}"/*/; do
		if [ -f "${SUBDIR}theme.ini" ]; then
			echo "${SUBDIR%/}"
			return
		fi
	done

	# Fallback: assume nested structure
	echo "${REPO_PATH}/$(basename "${REPO_PATH}")"
}

# Print DIR as an absolute path, or fail if it isn't a readable folder. A leading ~ is expanded here, since the shell leaves --localplugins=~/dir alone
absolute_dir() {
	local D=$1
	case $D in "~"|"~/"*) D=$HOME${D#\~} ;; esac
	[ -d "$D" ] && [ -r "$D" ] && cd -- "$D" 2>/dev/null && pwd -P
}

# collect_sources KIND DIR: sets FOUND to the plugin or theme folders in DIR (a plugin folder has a plugin.ini; a theme folder has a theme.ini in it or one level down) and skips anything else
collect_sources() {
	local KIND=$1 ENTRY SRC
	FOUND=()
	for ENTRY in "$2"/*/; do
		[ -d "$ENTRY" ] || continue
		ENTRY=${ENTRY%/}
		if [ "$KIND" = theme ]; then SRC=$(find_theme_dir "$ENTRY"); else SRC=$ENTRY; fi
		if [ -f "${SRC}/${KIND}.ini" ]; then
			FOUND+=("$SRC")
		else
			echo -e ${YELLOW}"█ Skipping ${ENTRY} (no ${KIND}.ini)" ${NOCOLOR}
		fi
	done
}

# ini_version FILE: prints the version from a plugin.ini or theme.ini (no quotes, no leading v), or nothing if there isn't one
ini_version() {
	[ -f "$1" ] || return 0
	grep -i -m 1 -E '^[[:space:]]*version[[:space:]]*=' "$1" | tr -d "\"'\r" | sed -E 's/^[^=]*=[[:space:]]*[vV]?//; s/[[:space:]]*(;.*)?$//'
}

# version_lt A B: true if version A sorts before version B
version_lt() {
	[ "$1" != "$2" ] && [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n 1)" = "$1" ]
}

# sync_item KIND SRC SITE: replaces SITE's copy of a plugin or theme folder with SRC (removing files SRC doesn't have), unless the installed copy has a newer version, or has a version when SRC doesn't. Adds to SITE_NOTES.
sync_item() {
	local KIND=$1 SRC=$2 SITE=$3 NAME DEST NEW OLD WAS WHY
	NAME=${SRC##*/}
	DEST="${SITE}/${KIND}s"
	NEW=$(ini_version "${SRC}/${KIND}.ini")
	OLD=$(ini_version "${DEST}/${NAME}/${KIND}.ini")
	if [ -n "$OLD" ] && { [ -z "$NEW" ] || version_lt "$NEW" "$OLD"; }; then
		if [ -z "$NEW" ]; then WHY="the new copy has no version number to compare"; else WHY="the new copy (${NEW}) is older"; fi
		echo -e ${YELLOW}"█ ${NAME}: keeping ${OLD}; ${WHY}" ${NOCOLOR}
		SITE_NOTES+="\n  ➡ Kept the installed ${NAME} ${KIND} (${OLD}); ${WHY}"
		return
	fi
	if [ -n "$OLD" ]; then WAS=$OLD; elif [ -d "${DEST}/${NAME}" ]; then WAS='no version'; else WAS='not installed'; fi
	if ! rsync -a --delete --exclude='.git/' "$SRC" "$DEST"; then
		echo -e ${RED}"█ ${NAME}: failed to sync" ${NOCOLOR}
		SITE_NOTES+="\n  ➡ Failed to sync the ${NAME} ${KIND} (see above for details)"
		return
	fi
	echo -e "█ ${NAME}: ${WAS} ➡ ${NEW:-no version}"
}

# OPTIONS: --localplugins=DIR or --localplugins DIR (same for --localthemes), before the paths
END_OF_OPTIONS=0
while [ $# -gt 0 ]; do
	case $1 in
		--)
			END_OF_OPTIONS=1
			shift
			break
			;;
		-h|--help)
			usage
			exit 0
			;;
		--localplugins|--localplugins=*|--localthemes|--localthemes=*)
			OPTION=${1%%=*}
			case $1 in
				*=*) VALUE=${1#*=} ;;
				*) if [ $# -ge 2 ]; then VALUE=$2; shift; else VALUE=''; fi ;;
			esac
			[ -n "$VALUE" ] || { echo -e "${RED}█ Option ${OPTION} needs a folder${NOCOLOR}"; usage; exit 1; }
			if [ "$OPTION" = --localplugins ]; then LOCAL_PLUGINS=$VALUE; else LOCAL_THEMES=$VALUE; fi
			;;
		-*)
			echo -e "${RED}█ Unknown option ${1%%=*}${NOCOLOR}"
			usage
			exit 1
			;;
		*)
			break
			;;
	esac
	shift
done

if [ $# -eq 0 ]
	then
		echo -e ${RED}"█ Oops, you forgot to include an argument! ${NOCOLOR}"
		usage
		exit 1
fi
if [ "$END_OF_OPTIONS" = 0 ]; then
	for SITE_RAW in "$@"; do
		case $SITE_RAW in -*) fatal "Options go before the paths ('${SITE_RAW}' came after a path)" ;; esac
	done
fi
[ "$(printf '%s\n' 1.10 1.9 | sort -V 2>/dev/null | head -n 1)" = 1.9 ] || fatal "This system's sort doesn't support -V, which is needed to compare plugin and theme versions"
if [ -n "$LOCAL_PLUGINS" ]; then
	ABS=$(absolute_dir "$LOCAL_PLUGINS") || fatal "Can't open the --localplugins folder '${LOCAL_PLUGINS}'"
	LOCAL_PLUGINS=$ABS
fi
if [ -n "$LOCAL_THEMES" ]; then
	ABS=$(absolute_dir "$LOCAL_THEMES") || fatal "Can't open the --localthemes folder '${LOCAL_THEMES}'"
	LOCAL_THEMES=$ABS
fi

echo -e ${CYAN}"Running Curatescape Utility from ${SCRIPT_LOCATION}/${ME}" ${NOCOLOR}

# LOCAL PLUGINS AND THEMES (checked before anything is downloaded)
if [ -n "$LOCAL_PLUGINS" ]
	then
		echo -e ${GREEN}"█ Using local plugins from ${LOCAL_PLUGINS} (skipping GitHub)" ${NOCOLOR}
		collect_sources plugin "$LOCAL_PLUGINS"
		[ ${#FOUND[@]} -gt 0 ] || fatal "No plugins in ${LOCAL_PLUGINS} (none of its folders has a plugin.ini). Point --localplugins at the folder that holds the plugin folders, e.g. curatescape_utility/plugins"
		PLUGIN_SOURCES=("${FOUND[@]}")
fi
if [ -n "$LOCAL_THEMES" ]
	then
		echo -e ${GREEN}"█ Using local themes from ${LOCAL_THEMES} (skipping GitHub)" ${NOCOLOR}
		collect_sources theme "$LOCAL_THEMES"
		[ ${#FOUND[@]} -gt 0 ] || fatal "No themes in ${LOCAL_THEMES} (none of its folders has a theme.ini). Point --localthemes at the folder that holds the theme folders, e.g. curatescape_utility/themes"
		THEME_SOURCES=("${FOUND[@]}")
fi

# GITHUB (only for whatever wasn't given a local folder)
if [ -z "$LOCAL_PLUGINS" ] || [ -z "$LOCAL_THEMES" ]
	then
		if ! [ -x "$(command -v git)" ]
			then
				echo -e ${RED}"█ ERROR: Git is missing or is not executable. Git is required for downloading plugins and themes from GitHub. Please install Git, use --localplugins and --localthemes, or use a manual method for adding/updating Curatescape tools." ${NOCOLOR}
				exit 1
		fi
		echo -e ${GREEN}"█ Git verified ($(git --version))" ${NOCOLOR}
		# WORKING DIRECTORY
		test -d $DIR || mkdir -p $DIR || { echo -e "${RED}█ Unable to create working directory at ${DIR} ${NOCOLOR}"; exit 2; }
		echo -e ${GREEN}"█ Working directory verified ('${DIR}')" ${NOCOLOR}
fi
if [ -z "$LOCAL_PLUGINS" ]
	then
		test -d $PLUGINS_DIR || mkdir -p $PLUGINS_DIR || { echo -e "${RED}█ Unable to create plugins working directory at ${PLUGINS_DIR} ${NOCOLOR}"; exit 2; }
		# PLUGINS
		echo -e ${GREEN}"█ Checking plugin repos ...\n" ${NOCOLOR}
		for REPO_SPEC in "${GITHUB_REPOS_PLUGINS[@]}"; do
			get_repo "$REPO_SPEC" "$PLUGINS_DIR" plugin-
		done
		collect_sources plugin "$PLUGINS_DIR"
		PLUGIN_SOURCES=("${FOUND[@]}")
fi
if [ -z "$LOCAL_THEMES" ]
	then
		test -d $THEMES_DIR || mkdir -p $THEMES_DIR || { echo -e "${RED}█ Unable to create themes working directory at ${THEMES_DIR} ${NOCOLOR}"; exit 2; }
		# THEMES
		echo -e ${GREEN}"█ Checking theme repos...\n" ${NOCOLOR}
		for REPO_SPEC in "${GITHUB_REPOS_THEMES[@]}"; do
			get_repo "$REPO_SPEC" "$THEMES_DIR" theme-
		done
		collect_sources theme "$THEMES_DIR"
		THEME_SOURCES=("${FOUND[@]}")
fi

# SITES
PLUGINS_FROM=${LOCAL_PLUGINS:-GitHub}
THEMES_FROM=${LOCAL_THEMES:-GitHub}
for SITE_RAW in "$@"; do
	SITE="${SITE_RAW%/}"
	if test -e "${SITE}/bootstrap.php" && grep -q OMEKA_VERSION "${SITE}/bootstrap.php"; then
		echo -e ${GREEN}"\n█ Omeka installation found at ${SITE}\n" ${NOCOLOR}
		SITE_NOTES=''
		echo -e ${CYAN}"█ Syncing required and optional plugins to ${SITE}/plugins ..." ${NOCOLOR}
		[ ${#PLUGIN_SOURCES[@]} -gt 0 ] || echo -e ${YELLOW}"█ No plugins to sync" ${NOCOLOR}
		for PLUGIN_PATH in "${PLUGIN_SOURCES[@]}"; do
			sync_item plugin "$PLUGIN_PATH" "$SITE"
		done
		echo -e ${CYAN}"\n█ Syncing recommended themes to ${SITE}/themes ..." ${NOCOLOR}
		[ ${#THEME_SOURCES[@]} -gt 0 ] || echo -e ${YELLOW}"█ No themes to sync" ${NOCOLOR}
		for THEME_PATH in "${THEME_SOURCES[@]}"; do
			sync_item theme "$THEME_PATH" "$SITE"
		done
		SUMMARY+="\n${GREEN}${BOLD}✔ ${SITE}:${NORMAL}${NOCOLOR}\n  ➡ Synced plugins from ${PLUGINS_FROM} and themes from ${THEMES_FROM}.${SITE_NOTES}\n  ➡ Be sure to log into your site to complete the installation/upgrade\n"${NOCOLOR}
	else
		echo -e ${YELLOW}"\n█ Omeka installation not found at ${SITE}. Skipping this directory.\n" ${NOCOLOR}
		SUMMARY+="\n${YELLOW}${BOLD}✗ ${SITE}:${NORMAL}${NOCOLOR}\n  ➡ Skipped (not an Omeka installation)\n"${NOCOLOR}
	fi
done
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
echo -e ${CYAN}"\n\n${SUMMARY}\n\n" ${NOCOLOR}
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
