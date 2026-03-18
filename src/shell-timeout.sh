# shellcheck shell=bash
# ----------------------------------------------------------------------
# Default configuration locations
# ----------------------------------------------------------------------
BASECFG=/etc/default/shell-timeout
CFGDIR=/etc/default/shell-timeout.d

# ----------------------------------------------------------------------
# POSIX‑compatible helper functions
# ----------------------------------------------------------------------

# Parse shell‑neutral config files (KEY=VALUE format)
_parse_config() {
    while IFS='=' read -r _key _value; do
        # Skip empty lines and comments
        case "${_key}" in
            '' | '#'*) continue ;;
        esac

        # Trim whitespace from key
        _key=$(printf '%s' "${_key}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        # Trim whitespace and surrounding quotes from value
        _value=$(printf '%s' "${_value}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/^["'"'"'"]//;s/["'"'"'"]$//')

        # Set variables based on key
        case "${_key}" in
            TMOUT_SECONDS) TMOUT_SECONDS="${_value}" ;;
            TMOUT_READONLY) TMOUT_READONLY="${_value}" ;;
            TMOUT_UIDS) TMOUT_UIDS="${TMOUT_UIDS-} ${_value}" ;;
            TMOUT_UIDS_NOCHECK) TMOUT_UIDS_NOCHECK="${TMOUT_UIDS_NOCHECK-} ${_value}" ;;
            TMOUT_GIDS) TMOUT_GIDS="${TMOUT_GIDS-} ${_value}" ;;
            TMOUT_GIDS_NOCHECK) TMOUT_GIDS_NOCHECK="${TMOUT_GIDS_NOCHECK-} ${_value}" ;;
            TMOUT_USERNAMES) TMOUT_USERNAMES="${TMOUT_USERNAMES-} ${_value}" ;;
            TMOUT_USERNAMES_NOCHECK) TMOUT_USERNAMES_NOCHECK="${TMOUT_USERNAMES_NOCHECK-} ${_value}" ;;
            TMOUT_GROUPS) TMOUT_GROUPS="${TMOUT_GROUPS-} ${_value}" ;;
            TMOUT_GROUPS_NOCHECK) TMOUT_GROUPS_NOCHECK="${TMOUT_GROUPS_NOCHECK-} ${_value}" ;;
        esac
    done <"$1"
}

# Normalize whitespace for cleanup
_norm_list() {
    # shellcheck disable=SC2086
    set -- $1
    printf '%s\n' "$*"
}

# Remove items in $2 from list $1
_subtract_list() {
    _out=
    # shellcheck disable=SC2086
    for _i in $(printf '%s\n' $1); do
        # shellcheck disable=SC2086
        case " $2 " in
            *" ${_i} "*) ;;
            *) _out="${_out} ${_i}" ;;
        esac
    done
    printf '%s\n' "${_out# }"
}

# ----------------------------------------------------------------------
# Read and parse configuration files
# ----------------------------------------------------------------------
[ -r "${BASECFG}" ] && _parse_config "${BASECFG}"

if [ -d "${CFGDIR}" ]; then
    for _f in $(printf '%s\n' "${CFGDIR}"/*.conf 2>/dev/null); do
        [ -r "${_f}" ] && _parse_config "${_f}"
    done
fi

# ----------------------------------------------------------------------
# Validate TMOUT_SECONDS (must be a positive integer)
# ----------------------------------------------------------------------
# shellcheck disable=SC2317
case ${TMOUT_SECONDS-} in
    '' | *[!0-9]* | 0) return 0 2>/dev/null || exit 0 ;;
esac

# ----------------------------------------------------------------------
# Resolve usernames and group names to numeric IDs
# ----------------------------------------------------------------------

# Resolve usernames to UIDs and append to TMOUT_UIDS
# shellcheck disable=SC2086
for _name in $(printf '%s\n' ${TMOUT_USERNAMES-}); do
    _uid=$(getent passwd "${_name}" 2>/dev/null | cut -d: -f3)
    [ -n "${_uid}" ] && TMOUT_UIDS="${TMOUT_UIDS-} ${_uid}"
done

# Resolve nocheck usernames to UIDs and append to TMOUT_UIDS_NOCHECK
# shellcheck disable=SC2086
for _name in $(printf '%s\n' ${TMOUT_USERNAMES_NOCHECK-}); do
    _uid=$(getent passwd "${_name}" 2>/dev/null | cut -d: -f3)
    [ -n "${_uid}" ] && TMOUT_UIDS_NOCHECK="${TMOUT_UIDS_NOCHECK-} ${_uid}"
done

# Resolve group names to GIDs and append to TMOUT_GIDS
# shellcheck disable=SC2086
for _name in $(printf '%s\n' ${TMOUT_GROUPS-}); do
    _gid=$(getent group "${_name}" 2>/dev/null | cut -d: -f3)
    [ -n "${_gid}" ] && TMOUT_GIDS="${TMOUT_GIDS-} ${_gid}"
done

# Resolve nocheck group names to GIDs and append to TMOUT_GIDS_NOCHECK
# shellcheck disable=SC2086
for _name in $(printf '%s\n' ${TMOUT_GROUPS_NOCHECK-}); do
    _gid=$(getent group "${_name}" 2>/dev/null | cut -d: -f3)
    [ -n "${_gid}" ] && TMOUT_GIDS_NOCHECK="${TMOUT_GIDS_NOCHECK-} ${_gid}"
done

# ----------------------------------------------------------------------
# Normalise and merge UID/GID lists
# ----------------------------------------------------------------------
TMOUT_UIDS=$(_norm_list "${TMOUT_UIDS-}")
TMOUT_UIDS_NOCHECK=$(_norm_list "${TMOUT_UIDS_NOCHECK-}")

TMOUT_GIDS=$(_norm_list "${TMOUT_GIDS-}")
TMOUT_GIDS_NOCHECK=$(_norm_list "${TMOUT_GIDS_NOCHECK-}")

# Apply removals
TMOUT_UIDS=$(_subtract_list "${TMOUT_UIDS}" "${TMOUT_UIDS_NOCHECK}")
TMOUT_GIDS=$(_subtract_list "${TMOUT_GIDS}" "${TMOUT_GIDS_NOCHECK}")

# ----------------------------------------------------------------------
# ID matching logic
# ----------------------------------------------------------------------
_match=

# Does UID match?
# shellcheck disable=SC2086
for _u in $(printf '%s\n' ${TMOUT_UIDS}); do
    [ "${_u}" = "${UID}" ] && _match=yes && break
done

# Does GID (primary or secondary) match?
if [ -z "${_match}" ] && [ -n "${TMOUT_GIDS}" ]; then
    for _gid in $(id -G 2>/dev/null); do
        # shellcheck disable=SC2086
        for _g in $(printf '%s\n' ${TMOUT_GIDS}); do
            [ "${_g}" = "${_gid}" ] && _match=yes && break 2
        done
    done
fi

# ----------------------------------------------------------------------
# Set TMOUT if a match was found
# ----------------------------------------------------------------------
if [ -n "$_match" ]; then
    TMOUT=${TMOUT_SECONDS}
    export TMOUT

    case ${TMOUT_READONLY-} in
        yes | YES | true | TRUE | 1) readonly TMOUT ;;
    esac
fi

# ----------------------------------------------------------------------
# Cleanup
# ----------------------------------------------------------------------
unset BASECFG CFGDIR
unset _f _i _u _g _gid _match _key _value _out _name _uid
unset TMOUT_SECONDS TMOUT_READONLY
unset TMOUT_UIDS TMOUT_UIDS_NOCHECK
unset TMOUT_GIDS TMOUT_GIDS_NOCHECK
unset TMOUT_USERNAMES TMOUT_USERNAMES_NOCHECK
unset TMOUT_GROUPS TMOUT_GROUPS_NOCHECK
unset -f _parse_config _norm_list _subtract_list
