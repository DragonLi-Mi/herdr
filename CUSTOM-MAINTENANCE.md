# Custom Herdr maintenance

This fork follows upstream stable releases, not the moving upstream master.
The current base is **v0.9.4**, and the custom build is **0.9.4-custom.1**.
Do not use upstream release recipes or modify upstream distribution manifests.

## Branches and patches

- `master`: unmodified upstream default branch mirror; never add custom commits.
- `custom/stable`: reviewed stable base plus our small custom patch stack.
- `feature/tab-wheel-toggle`: original v0.9.3 implementation, kept as history.

The wheel-toggle patch originated in commit
`5e65d7ff532c8a26db5ad581eb688df25688fc4d`.
It adds `ui.tab_bar_scroll_switch` (default `true`) only to the client.
Set it to `false` to suppress wheel-based tab switching without disabling clicks,
dragging, or pane scrolling. Live configuration reload is supported.
Upstream discussion: https://github.com/herdrdev/herdr/discussions/5216.
Remove this patch once an upstream stable release provides equivalent behavior.

The separate maintenance commit supplies custom build identity, an official
updater guard, isolated Windows installation, and the fork-only build workflow.
There are no runtime protocol changes.

## Upgrade procedure

1. Fetch `upstream` and its tags. Review the latest stable release and whether
   upstream has replaced any of our patches. Never move or overwrite upstream tags.
2. Create `upgrade/<version>` from that stable tag. Cherry-pick each still-needed
   custom commit in order, resolving conflicts against the new implementation.
3. Keep `Cargo.toml` at the upstream base version. Set the custom build ID in
   `src/build_info.rs` and `.github/workflows/custom-windows.yml` together.
   Update the base version recorded in this document and the workflow.
4. Run `just check` and `just build` with the repository's native Windows toolchain.
   Document baseline/environment failures separately; do not silently skip them.
   Verify disabled/enabled wheel behavior, tab clicks/dragging, pane scrolling,
   config reload, version identity, and refusal of `herdr update`.
5. Integrate into `custom/stable` without force-pushing a shared branch. For an
   upgrade rebuilt directly on a new tag, merge the reviewed upgrade branch with
   `git merge --no-ff upgrade/<version>` so published history stays intact.
   Review the resulting diff against the new upstream tag for unintended changes.
6. Create and push `v<upstream-version>-custom.<build-id>` only after validation.
   `Custom Windows release` tests, builds, packages the verified ConPTY runtime,
   and publishes assets to this fork. Manual dispatch creates an artifact only.
   Never retag a published build; increment the custom build ID for a rebuild.
7. Review/download the release, verify `SHA256SUMS`, and install explicitly.
   No workflow automatically replaces a user's running installation.

Sync the clean mirror independently using a fast-forward-only update:

```powershell
git fetch upstream master:refs/remotes/upstream/master --tags
git push origin refs/remotes/upstream/master:refs/heads/master
```

If the push is not a fast-forward, investigate instead of force-pushing.

## Windows installation and configuration

Use PowerShell 7 (`pwsh`), not Windows PowerShell 5.1.
Download the archive and `install-custom.ps1` from this fork's release.
Only run packages you trust, and verify the archive hash against `SHA256SUMS`.

```powershell
.\install-custom.ps1 -ArchivePath .\herdr-custom-windows-x86_64.zip
```

The installer retains versioned builds in `~\.herdr-custom\releases`, places
`herdr.cmd` and `herdr-custom-update.ps1` in `~\.herdr-custom\bin`, and prepends
that directory to the user PATH. It preserves the official installation,
running servers, and configuration. Open a new terminal for PATH changes.
Existing TUI clients must reconnect to use the new client-side behavior.
An official server of the same compatible version can keep running.

In `%APPDATA%\herdr\config.toml`, keep:

```toml
[ui]
mouse_capture = true
tab_bar_scroll_switch = false
```

Validate with `herdr config check` and reload with `herdr server reload-config`.
An existing official server may report this client-only key as unknown and return
a partial reload; reconnect using the custom client to apply the setting.
Do not stop a running server merely to remove that diagnostic.
The custom build refuses `herdr update` before contacting upstream. Official
update notices are disabled; review upstream releases as part of maintenance.
For the next reviewed custom archive:

```powershell
herdr-custom-update.ps1 -ArchivePath .\herdr-custom-windows-x86_64.zip
```

For rollback, run the installer with a retained previous custom archive; it
repoints the launcher without overwriting a running executable. Retain config
backups before changing settings. To use an official build instead, invoke its
full executable path and remove/comment custom-only keys after backing up config.
