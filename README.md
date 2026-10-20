# dots-bootstrap

Sets up a fresh machine from your dotfiles with nothing but pixi.

## What it does

0. Windows only: makes sure Developer Mode is on (dotfiles are symlinks).
1. Logs in to GitHub with `gh` (skipped if already logged in), then sets up git credentials and git-lfs.
2. Sets your global git name and email if they are empty.
3. Clones your dotfiles repo (skipped if already cloned).
4. Optionally clones a private companion repo into `<dotfiles>/private` (skipped if present or left blank).
5. Runs your dotfiles' `scripts/install.nu`.

## What your dotfiles repo needs

A `scripts/install.nu` at its root, run with `nu --no-config-file`. An optional private companion repo is cloned to `<dotfiles>/private`, and what your dotfiles do with it is up to them.

## Fresh machine

```bash
curl -fsSL https://pixi.sh/install.sh | sh
export PATH="$HOME/.pixi/bin:$PATH"
pixi global install git
pixi global install --git https://github.com/jackm97/dots-bootstrap.git dots-bootstrap
dots-bootstrap
```

```powershell
powershell -ExecutionPolicy Bypass -c "irm -useb https://pixi.sh/install.ps1 | iex"
$env:Path = "$env:USERPROFILE\.pixi\bin;$env:Path"
pixi global install git
pixi global install --git https://github.com/jackm97/dots-bootstrap.git dots-bootstrap
dots-bootstrap
```

## Re-running

Safe: every step skips what is already done.

## Windows

Developer Mode is required, and the tool walks you through turning it on.
