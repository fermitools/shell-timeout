# ----------------------------------------------------------------------
# Configuration locations
# ----------------------------------------------------------------------
set BASECFG = /etc/default/shell-timeout
set CFGDIR  = /etc/default/shell-timeout.d

# ----------------------------------------------------------------------
# Variables that will be filled while parsing the config files
# ----------------------------------------------------------------------
set TMOUT_SECONDS       = ""
set TMOUT_READONLY      = ""
set TMOUT_UIDS          = ""
set TMOUT_UIDS_NOCHECK  = ""
set TMOUT_GIDS          = ""
set TMOUT_GIDS_NOCHECK  = ""

# ----------------------------------------------------------------------
# Helper: trim leading/trailing whitespace and surrounding quotes
# ----------------------------------------------------------------------
proc trim {
    # $1 = string to trim
    echo "$1" | \
        sed -e 's/^[[:space:]]*//' \
            -e 's/[[:space:]]*$//' \
            -e 's/^["'"'"']//' \
            -e 's/["'"'"']$//'
}

# ----------------------------------------------------------------------
# Parse a single config file (KEY=VALUE lines, ignore comments)
# ----------------------------------------------------------------------
proc _parse_config {
    set file = "$1"
    if ( ! -r "$file" ) then
        return
    endif

    while ( "$<" "$file" )
        set line = "$_"

        # skip empty lines or lines that start with '#'
        if ( "$line" == "" ) then continue; endif
        if ( "$line[1]" == "#" ) then continue; endif

        # split on the first '='
        set key   = `echo "$line" | sed 's/=.*//'`
        set value = `echo "$line" | sed 's/^[^=]*=//'`

        # normalise using the trim function
        set key   = `trim "$key"`
        set value = `trim "$value"`

        switch ( "$key" )
            case TMOUT_SECONDS:
                set TMOUT_SECONDS = "$value"
                breaksw
            case TMOUT_READONLY:
                set TMOUT_READONLY = "$value"
                breaksw
            case TMOUT_UIDS:
                set TMOUT_UIDS = "$TMOUT_UIDS $value"
                breaksw
            case TMOUT_UIDS_NOCHECK:
                set TMOUT_UIDS_NOCHECK = "$TMOUT_UIDS_NOCHECK $value"
                breaksw
            case TMOUT_GIDS:
                set TMOUT_GIDS = "$TMOUT_GIDS $value"
                breaksw
            case TMOUT_GIDS_NOCHECK:
                set TMOUT_GIDS_NOCHECK = "$TMOUT_GIDS_NOCHECK $value"
                breaksw
        endsw
    end
}

# ----------------------------------------------------------------------
# Load main config and any *.conf files in $CFGDIR
# ----------------------------------------------------------------------
if ( -r "$BASECFG" ) then
    _parse_config "$BASECFG"
endif

if ( -d "$CFGDIR" ) then
    foreach f ( "$CFGDIR"/*.conf )
        if ( -r "$f" ) then
            _parse_config "$f"
        endif
    end
endif

# ----------------------------------------------------------------------
# Validate TMOUT_SECONDS (must be a positive integer)
# ----------------------------------------------------------------------
if ( "$TMOUT_SECONDS" !~ [0-9]* || "$TMOUT_SECONDS" == "" || "$TMOUT_SECONDS" == "0" ) then
    exit 0
endif

# ----------------------------------------------------------------------
# Normalise whitespace (collapse multiples, strip leading/trailing)
# ----------------------------------------------------------------------
set TMOUT_UIDS        = `echo $TMOUT_UIDS        | tr -s ' ' '\n' | sort -u | tr '\n' ' '`
set TMOUT_UIDS_NOCHECK = `echo $TMOUT_UIDS_NOCHECK | tr -s ' ' '\n' | sort -u | tr '\n' ' '`
set TMOUT_GIDS        = `echo $TMOUT_GIDS        | tr -s ' ' '\n' | sort -u | tr '\n' ' '`
set TMOUT_GIDS_NOCHECK = `echo $TMOUT_GIDS_NOCHECK | tr -s ' ' '\n' | sort -u | tr '\n' ' '`

# ----------------------------------------------------------------------
# Apply removals
# ----------------------------------------------------------------------
set new_uids = ""
foreach u ( $TMOUT_UIDS )
    if ( "$TMOUT_UIDS_NOCHECK" !~ "* $u *" ) then
        set new_uids = "$new_uids $u"
    endif
end
set TMOUT_UIDS = "$new_uids"

set new_gids = ""
foreach g ( $TMOUT_GIDS )
    if ( "$TMOUT_GIDS_NOCHECK" !~ "* $g *" ) then
        set new_gids = "$new_gids $g"
    endif
end
set TMOUT_GIDS = "$new_gids"

# ----------------------------------------------------------------------
# Matching logic – does the current user or any of its groups appear?
# ----------------------------------------------------------------------
set _match = 0

# UID match
foreach u ( $TMOUT_UIDS )
    if ( "$u" == "$UID" ) then
        set _match = 1
        break
    endif
end

# GID match (primary + supplementary)
if ( $_match == 0 && "$TMOUT_GIDS" != "" ) then
    foreach gid ( `id -G 2>/dev/null` )
        foreach g ( $TMOUT_GIDS )
            if ( "$g" == "$gid" ) then
                set _match = 1
                break 2
            endif
        end
    end
endif

# ----------------------------------------------------------------------
# If a match was found, set autologout
# ----------------------------------------------------------------------
if ( $_match == 1 ) then
    @ _autologout_min = "$TMOUT_SECONDS" / 60

    if ( $_autologout_min < 1 ) then
        @ _autologout_min = 1
    endif

    set autologout = $_autologout_min

    if ( $?TMOUT_READONLY ) then
        switch ( "$TMOUT_READONLY" )
            case yes:
            case YES:
            case true:
            case TRUE:
            case 1:
                set -r autologout
                breaksw
        endsw
    endif
endif

# ----------------------------------------------------------------------
# Cleanup temporary variables
# ----------------------------------------------------------------------
unset BASECFG CFGDIR
unset file line key value
unset new_uids new_gids
unset _match u g gid
unset TMOUT_SECONDS TMOUT_READONLY _autologout_min
unset TMOUT_UIDS TMOUT_UIDS_NOCHECK TMOUT_GIDS TMOUT_GIDS_NOCHECK
unset -f _parse_config trim
