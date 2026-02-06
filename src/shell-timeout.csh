# ----------------------------------------------------------------------
# Guard: interactive shells only
# ----------------------------------------------------------------------
if ( ! $?prompt ) exit

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
set TMOUT_UIDS          = ()
set TMOUT_UIDS_NOCHECK  = ()
set TMOUT_GIDS          = ()
set TMOUT_GIDS_NOCHECK  = ()

# ----------------------------------------------------------------------
# Prepare config files list safely
# ----------------------------------------------------------------------
set cfgs = ( $BASECFG )
if ( -d $CFGDIR ) then
    # Only add .conf files if they exist to avoid empty glob error
    if ( -e $CFGDIR/*.conf ) then
        set cfgs = ( $cfgs $CFGDIR/*.conf )
    endif
endif

# ----------------------------------------------------------------------
# Parse config files
# ----------------------------------------------------------------------
foreach cfg ( $cfgs )
    if ( ! -r "$cfg" ) continue

    # Use grep to filter comments and blank lines
    foreach line ( `grep -v '^\s*#' "$cfg" | grep -v '^\s*$'` )
        # Extract key and value
        set key = `echo $line | cut -d '=' -f 1`
        set value = `echo $line | cut -d '=' -f 2- | sed 's/^[ \t]*//;s/[ \t]*$//' | sed 's/^"//;s/"$//' | sed "s/^'//;s/'$//"`

        switch ( "$key" )
            case TMOUT_SECONDS:
                set TMOUT_SECONDS = "$value"
                breaksw
            case TMOUT_READONLY:
                set TMOUT_READONLY = "$value"
                breaksw
            case TMOUT_UIDS:
                set TMOUT_UIDS = ( $TMOUT_UIDS $value )
                breaksw
            case TMOUT_UIDS_NOCHECK:
                set TMOUT_UIDS_NOCHECK = ( $TMOUT_UIDS_NOCHECK $value )
                breaksw
            case TMOUT_GIDS:
                set TMOUT_GIDS = ( $TMOUT_GIDS $value )
                breaksw
            case TMOUT_GIDS_NOCHECK:
                set TMOUT_GIDS_NOCHECK = ( $TMOUT_GIDS_NOCHECK $value )
                breaksw
        endsw
    end
end

# ----------------------------------------------------------------------
# Validate TMOUT_SECONDS
# ----------------------------------------------------------------------
if ( "$TMOUT_SECONDS" !~ [0-9]* || "$TMOUT_SECONDS" == "" || "$TMOUT_SECONDS" == "0" ) exit

# ----------------------------------------------------------------------
# Apply removals
# ----------------------------------------------------------------------
set _uids = ()
foreach __u ( $TMOUT_UIDS )
    if ( "$TMOUT_UIDS_NOCHECK" !~ "* $__u *" ) set _uids = ( $_uids $__u )
end
set TMOUT_UIDS = ( $_uids )

set _gids = ()
foreach __g ( $TMOUT_GIDS )
    if ( "$TMOUT_GIDS_NOCHECK" !~ "* $__g *" ) set _gids = ( $_gids $__g )
end
set TMOUT_GIDS = ( $_gids )

# ----------------------------------------------------------------------
# Match UID / GID
# ----------------------------------------------------------------------
set _match = 0

foreach __u ( $TMOUT_UIDS )
    if ( "$__u" == "$UID" ) then
        set _match = 1
        break
    endif
end

if ( $_match == 0 ) then
    foreach _gid ( `id -G` )
        foreach __g ( $TMOUT_GIDS )
            if ( "$__g" == "$_gid" ) then
                set _match = 1
                break 2
            endif
        end
    end
endif

# ----------------------------------------------------------------------
# Apply autologout
# ----------------------------------------------------------------------
if ( $_match ) then
    @ autologout = $TMOUT_SECONDS / 60
    if ( $autologout < 1 ) @ autologout = 1

    if ( "$TMOUT_READONLY" =~ [Yy][Ee][Ss] || "$TMOUT_READONLY" =~ [Tt][Rr][Uu][Ee] || "$TMOUT_READONLY" == "1" ) then
        set -r autologout
    endif
endif

# ----------------------------------------------------------------------
# Cleanup
# ----------------------------------------------------------------------
unset BASECFG CFGDIR
unset TMOUT_SECONDS TMOUT_READONLY
unset TMOUT_UIDS TMOUT_UIDS_NOCHECK
unset TMOUT_GIDS TMOUT_GIDS_NOCHECK
unset cfg line key value
unset _uids _gids __u __g _gid _match
