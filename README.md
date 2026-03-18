# Shell Timeout Scripts

Automatic shell timeout configuration scripts for POSIX shells (bash/zsh) and C shells (csh/tcsh).

## Overview

These scripts automatically set shell timeout values based on User ID (UID) or Group ID (GID) membership (including secondary groups). When a matching user logs in, their shell will automatically terminate after a configured period of inactivity.

**NOTE**: Not all shells implement this feature.

## Features

- UID and/or GID-based timeout configuration
- Username and group name-based timeout configuration (resolved to UIDs/GIDs at runtime)
- Additive and subtractive list management (mix numeric IDs and names freely)
- Per-user/group readonly exemption (`TMOUT_*_NOREADONLY`) - global readonly can be set while allowing specific trusted users to override their timeout
- Validation of timeout values (positive integers only)
- Can set timeout to readonly (bash/zsh)

## Files

- `shell-timeout.sh` - POSIX shell (bash/zsh) compatible version
- `shell-timeout.csh` - C shell (csh/tcsh) compatible version
- `shell-timeout` - Config file

## Installation

### Config files

1. Create the configuration directory:
   ```bash
   sudo mkdir -p /etc/default/shell-timeout.d
   ```

2. Create the main configuration file:
   ```bash
   sudo touch /etc/default/shell-timeout
   ```

### POSIX Shells (bash/zsh)

1. Copy the script to the profile directory:
   ```bash
   sudo cp shell-timeout.sh /etc/profile.d/shell-timeout.sh
   sudo chmod 644 /etc/profile.d/shell-timeout.sh
   ```
### C Shells (csh/tcsh)

1. Copy the script to the appropriate location:
   ```bash
   sudo cp shell-timeout.csh /etc/profile.d/shell-timeout.csh
   sudo chmod 644 /etc/profile.d/shell-timeout.csh
   ```

## Configuration

### Configuration File Format

Configuration files use a **shell-neutral KEY=VALUE format** that works with both POSIX and C shells. This means you can use the same configuration files for all shell types.

### Main Configuration File

Edit `/etc/default/shell-timeout`:

```ini
# Timeout in seconds (POSIX shells) or converted to minutes (csh)
TMOUT_SECONDS=900

# Space-separated list of UIDs to apply timeout
TMOUT_UIDS=1000 1001 1002

# Space-separated list of GIDs to apply timeout
TMOUT_GIDS=100 200

# Make timeout readonly (prevents users from changing it)
# Only works in POSIX shells - ignored in csh/tcsh
TMOUT_READONLY=yes
```

**Important formatting rules:**
- Use `KEY=VALUE` format (no spaces around `=`)
- Values can be quoted or unquoted
- Multiple values separated by spaces
- Comments start with `#`
- Empty lines are ignored

### Drop-in Configuration Files

Additional configurations can be placed in `/etc/default/shell-timeout.d/*.conf`:

Example `/etc/default/shell-timeout.d/developers.conf`:
```ini
# Add a specific user to timeout list by name
TMOUT_USERNAMES=jsmith

# Add developer group by name
TMOUT_GROUPS=developers

# Remove specific user from timeout (by UID or name)
TMOUT_UIDS_NOCHECK=1000
TMOUT_USERNAMES_NOCHECK=alice
```

**Note:** Later configuration files extend earlier ones. Drop-in files are processed in alphabetical order.
          If we used both examples listed here `TMOUT_UIDS=1001 1002` and `TMOUT_GIDS=100 200 500`

### Configuration Variables

|  Variable                   |  Description  |
|-----------------------------|---------------|
| `TMOUT_SECONDS`             | Timeout duration in seconds (must be positive integer)                                             |
| `TMOUT_READONLY`            | Set to `yes`/`true`/`1` to make timeout readonly - **POSIX shells only**                           |
| `TMOUT_UIDS`                | Space-separated UIDs to apply timeout; all values merged                                           |
| `TMOUT_GIDS`                | Space-separated GIDs to apply timeout; all values merged                                           |
| `TMOUT_USERNAMES`           | Space-separated usernames to apply timeout; resolved to UIDs at runtime                            |
| `TMOUT_GROUPS`              | Space-separated group names to apply timeout; resolved to GIDs at runtime                          |
| `TMOUT_UIDS_NOCHECK`        | UIDs to remove from consideration; all values merged                                               |
| `TMOUT_GIDS_NOCHECK`        | GIDs to remove from consideration; all values merged                                               |
| `TMOUT_USERNAMES_NOCHECK`   | Usernames to remove from consideration; resolved to UIDs at runtime                                |
| `TMOUT_GROUPS_NOCHECK`      | Group names to remove from consideration; resolved to GIDs at runtime                              |
| `TMOUT_UIDS_NOREADONLY`     | UIDs exempt from readonly enforcement; timeout is still set but not locked - **POSIX shells only** |
| `TMOUT_GIDS_NOREADONLY`     | GIDs exempt from readonly enforcement - **POSIX shells only**                                      |
| `TMOUT_USERNAMES_NOREADONLY`| Usernames exempt from readonly enforcement; resolved to UIDs at runtime - **POSIX shells only**    |
| `TMOUT_GROUPS_NOREADONLY`   | Group names exempt from readonly enforcement; resolved to GIDs at runtime - **POSIX shells only**  |

Numeric IDs (`TMOUT_UIDS`, `TMOUT_GIDS` and their `_NOCHECK`/`_NOREADONLY` variants) and
name-based entries (`TMOUT_USERNAMES`, `TMOUT_GROUPS` and their `_NOCHECK`/`_NOREADONLY`
variants) can be mixed freely - they are resolved to the same internal lists before matching.

## How It Works

1. Scripts load configuration from `/etc/default/shell-timeout`
2. Drop-in configs from `/etc/default/shell-timeout.d/*.conf` are sourced
3. Usernames in `TMOUT_USERNAMES`/`TMOUT_USERNAMES_NOCHECK`/`TMOUT_USERNAMES_NOREADONLY` are resolved to UIDs via `getent passwd`
4. Group names in `TMOUT_GROUPS`/`TMOUT_GROUPS_NOCHECK`/`TMOUT_GROUPS_NOREADONLY` are resolved to GIDs via `getent group`
5. UID/GID lists are merged (base + name-resolved + drop-ins) then NOCHECK removals applied
6. `TMOUT_SECONDS` is validated (must be positive integer)
7. Current user's UID and GIDs (primary + secondary) are checked against the final lists
8. If a match is found, timeout is set:
   - **POSIX shells**: Sets `TMOUT` environment variable (in seconds)
   - **C shells**: Sets `autologout` variable (converted to minutes, minimum 1)
9. If `TMOUT_READONLY=yes` and the user is **not** in any `_NOREADONLY` list, `TMOUT` is made readonly (POSIX shells only)

The UID and GID matching paths are **fully independent**: removing an entry from
the UID list (via `TMOUT_UIDS_NOCHECK` or `TMOUT_USERNAMES_NOCHECK`) has no effect
on GID matching, and vice versa.

The `_NOREADONLY` lists follow the same semantics: a user whose UID is in
`TMOUT_UIDS_NOREADONLY` is exempt from readonly enforcement regardless of whether
the match came from the UID or GID path.  Exemption via GID (`TMOUT_GIDS_NOREADONLY`)
works symmetrically.

### Example:

If you have groups of `0`, `100`, `1000`, each of the following configs would match your account.

```ini
TMOUT_GIDS=0 100
```

```ini
TMOUT_GIDS=0 100
TMOUT_GIDS_NOCHECK=100
```

```ini
TMOUT_GIDS=0 100 1000
TMOUT_GIDS_NOCHECK=0 1000
```

The all three cases are functionally equivalent.

## Shell Differences

### POSIX Shells (bash/zsh)
- Uses `TMOUT` variable (seconds)
- Exact timeout granularity
- Supports readonly enforcement via `readonly TMOUT`

### C Shells (csh/tcsh)
- Uses `autologout` variable (minutes)
- Converts seconds to minutes (rounds down, minimum 1 minute)
- Cannot enforce readonly `autologout`

## Examples

### Example 1: Timeout for specific group

`/etc/default/shell-timeout`:
```ini
TMOUT_SECONDS=1800
TMOUT_GIDS=500
TMOUT_READONLY=yes
```

### Example 2: Base config with overrides

`/etc/default/shell-timeout`:
```ini
TMOUT_SECONDS=900
TMOUT_GIDS=100 200
```

`/etc/default/shell-timeout.d/exceptions.conf`:
```ini
# Add audit group by name
TMOUT_GROUPS=auditors

# Remove specific power users (mix of numeric and name)
TMOUT_UIDS_NOCHECK=1050 1051
TMOUT_USERNAMES_NOCHECK=svcaccount
```

### Example 3: Multiple UIDs/usernames with exceptions

`/etc/default/shell-timeout`:
```ini
TMOUT_SECONDS=600
TMOUT_UIDS=1000 1001 1002 1003 1004
```

`/etc/default/shell-timeout.d/admin-exception.conf`:
```ini
# Remove admins by name (equivalent to removing their UIDs)
TMOUT_USERNAMES_NOCHECK=alice bob
```

## Validation

The scripts validate `TMOUT_SECONDS` to ensure:
- It is not empty
- It contains only digits (0-9)
- It is greater than zero
- It is not a float/decimal

Invalid values cause the script to exit without setting a timeout.

## Security Considerations

- Use `TMOUT_READONLY=yes` in POSIX shells to prevent users from unsetting the timeout
  - "C shells" cannot enforce readonly - consider this when choosing the default shells for security-sensitive accounts
- Timeouts apply per-shell session, not per SSH connection or shell scripts
  - Consider combining with SSH timeout settings for comprehensive idle timeout
- Users can still use screen/tmux to maintain sessions, but idle shells may still terminate - it is a property of the shell

## Troubleshooting

### Timeout not applied
- Check that user's UID or GID is in the configured lists
- Verify configuration file syntax (no syntax errors)
- Test with: `getent` and `id` to see user's UID and GIDs
- Source the script manually to see any errors

### Timeout applied when unexpected
- Remember the `_NOCHECK` element state that the ID will not be explicitly selected
- Verify configuration file syntax (no syntax errors)
- Test with: `getent` and `id` to see user's UID and GIDs
- Verify no secondary group is in the configutation
- Source the script manually to see any errors

### Different timeout than expected
- Check for multiple configuration files overriding values
- Remember csh/tcsh converts to minutes (rounds down)
- Verify `TMOUT_SECONDS` is valid positive integer

### Script errors on login
- Check file permissions (should be 644)
- Verify configuration file syntax
- Look for shell-specific issues in `/var/log/messages`

## License

[GPL-3.0-or-later](LICENSE)

## Contributing

When modifying these scripts:
- Maintain POSIX compliance for `.sh` version
- Test on bash and zsh
- Test csh version on both csh and tcsh
- Update this README with any new features or changes
- Update tests with new workflows
