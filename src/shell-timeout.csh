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
    ls "$CFGDIR"/*.conf >& /dev/null
    if ( $status == 0 ) then
        set cfgs = ( $cfgs "$CFGDIR"/*.conf )
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
        set value = `echo $line | cut -d '=' -f 2- | sed 's/^[ \t]*//;s/[ \t]*$//' | sed 's/^"//;s/"$//' | sed 's/^'\''//;s/'\''$//'`

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
if ( "$TMOUT_SECONDS" =~ *.* ) exit

# ----------------------------------------------------------------------
# Apply removals (pad with spaces for proper pattern matching)
# ----------------------------------------------------------------------
set check_uids = " $TMOUT_UIDS_NOCHECK "
set uids = ()
foreach u__ ( $TMOUT_UIDS )
    if ( "$check_uids" !~ "* $u__ *" ) set uids = ( $uids $u__ )
end
set TMOUT_UIDS = ( $uids )

set check_gids = " $TMOUT_GIDS_NOCHECK "
set gids = ()
foreach g__ ( $TMOUT_GIDS )
    if ( "$check_gids" !~ "* $g__ *" ) set gids = ( $gids $g__ )
end
set TMOUT_GIDS = ( $gids )

# ----------------------------------------------------------------------
# Match UID / GID
# ----------------------------------------------------------------------
set match = 0
set CURRENT_UID = `id -u`

foreach u__ ( $TMOUT_UIDS )
    if ( "$u__" == "$CURRENT_UID" ) then
        set match = 1
        break
    endif
end

if ( $match == 0 ) then
    foreach gid ( `id -G` )
        foreach g__ ( $TMOUT_GIDS )
            if ( "$g__" == "$gid" ) then
                set match = 1
                break
            endif
        end
        if ( $match == 1 ) break
    end
endif

# ----------------------------------------------------------------------
# Apply autologout
# ----------------------------------------------------------------------
if ( $match ) then
    @ autologout_min = $TMOUT_SECONDS / 60
    if ( $autologout_min < 1 ) @ autologout_min = 1

    # csh doesn't support read-only variables
    set autologout = $autologout_min
endif

# ----------------------------------------------------------------------
# Cleanup
# ----------------------------------------------------------------------
unset BASECFG CFGDIR
unset TMOUT_SECONDS TMOUT_READONLY
unset TMOUT_UIDS TMOUT_UIDS_NOCHECK
unset TMOUT_GIDS TMOUT_GIDS_NOCHECK
unset cfg line key value autologout_min
unset uids gids u__ g__ gid match CURRENT_UID
