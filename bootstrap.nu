#!/usr/bin/env nu

# Ask a question; a blank answer returns the default, shown in brackets.
def ask [prompt: string, default: string] {
    let answer = (input $"($prompt) [($default)]: " | str trim)
    if ($answer | is-empty) { $default } else { $answer }
}

# Is Windows Developer Mode on? Failure to read counts as off.
# The registry command only exists in Windows builds of nushell, so it runs
# in a child nu as a string and never has to parse elsewhere.
def developer-mode-on [] {
    try {
        let out = (^nu --no-config-file -c r#'registry query --hklm 'SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' AllowDevelopmentWithoutDevLicense | get value | first | into string'# | str trim)
        $out == "1"
    } catch {
        false
    }
}

# Set up this machine from your dotfiles repo: GitHub login, clone your dotfiles (and optional private dotfiles), then run the repo's scripts/install.nu.
def main [] {
    # --- 0. Windows: Developer Mode ---------------------------------------
    if $nu.os-info.name == "windows" {
        print $"(ansi cyan)0/5(ansi reset) checking Windows Developer Mode"
        if (developer-mode-on) {
            print "  Developer Mode is on"
        } else {
            print "Your dotfiles are symlinks, and Windows only allows unprivileged symlinks with Developer Mode."
            ^cmd /c start ms-settings:developers
            loop {
                input "Press Enter once Developer Mode is on"
                if (developer-mode-on) { break }
                print "  still off"
            }
        }
    }

    # --- 1. GitHub ----------------------------------------------------------
    print $"(ansi cyan)1/5(ansi reset) GitHub login"
    let auth = (do { gh auth status } | complete)
    if $auth.exit_code != 0 {
        gh auth login --hostname github.com --git-protocol https --web
        if $env.LAST_EXIT_CODE != 0 {
            print $"(ansi red)GitHub login failed(ansi reset)"
            exit 1
        }
    } else {
        print "  already logged in"
    }
    gh auth setup-git
    git lfs install

    # --- 2. Git identity ----------------------------------------------------
    print $"(ansi cyan)2/5(ansi reset) git identity"
    let login = (gh api user --jq .login | str trim)
    if (git config --global user.name | str trim | is-empty) {
        let full = (gh api user --jq .name | str trim)
        let default_name = if ($full | is-empty) { $login } else { $full }
        git config --global user.name (ask "Git user name" $default_name)
    } else {
        print "  user.name already set"
    }
    if (git config --global user.email | str trim | is-empty) {
        let id = (gh api user --jq .id | str trim)
        git config --global user.email (ask "Git user email" $"($id)+($login)@users.noreply.github.com")
    } else {
        print "  user.email already set"
    }

    # --- 3. Dotfiles --------------------------------------------------------
    print $"(ansi cyan)3/5(ansi reset) dotfiles"
    let loc = (ask "Dotfiles location" "~/dotfiles" | path expand)
    if ($loc | path join ".git" | path exists) {
        print $"  already cloned at ($loc)"
    } else {
        let url = (ask "Dotfiles repo URL" $"https://github.com/($login)/dotfiles.git")
        git clone $url $loc
        if $env.LAST_EXIT_CODE != 0 {
            print $"(ansi red)clone failed(ansi reset)"
            exit 1
        }
    }

    # --- 4. Private dotfiles ------------------------------------------------
    print $"(ansi cyan)4/5(ansi reset) private dotfiles"
    let p = ($loc | path join "private")
    if ($p | path join ".git" | path exists) {
        print $"  already cloned at ($p)"
    } else {
        let url = (input "Private dotfiles repo URL (blank to skip): " | str trim)
        if ($url | is-empty) {
            print "  skipped"
        } else {
            git clone $url $p
            if $env.LAST_EXIT_CODE != 0 {
                print $"(ansi red)clone failed(ansi reset)"
                exit 1
            }
        }
    }

    # --- 5. Hand off --------------------------------------------------------
    print $"(ansi cyan)5/5(ansi reset) running your dotfiles' installer"
    let inst = ($loc | path join "scripts" "install.nu")
    if not ($inst | path exists) {
        print "no scripts/install.nu in your dotfiles; nothing more to do"
        exit 0
    }
    nu --no-config-file $inst
    let code = $env.LAST_EXIT_CODE
    if $code != 0 {
        print $"(ansi red)install.nu failed(ansi reset)"
    } else {
        print $"(ansi green)done(ansi reset)"
    }
    exit $code
}
