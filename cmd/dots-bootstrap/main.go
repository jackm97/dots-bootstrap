// dots-bootstrap is a thin launcher. pixi exposes executables, not .nu
// scripts, on every platform, so the nushell script that does the real work
// ships as data next to the binary and this wrapper is what gets exposed. It
// only finds the environment it lives in, puts that environment's bin
// directories on PATH, and hands off to `nu bootstrap.nu`.
package main

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
)

func fail(format string, a ...any) {
	fmt.Fprintf(os.Stderr, "dots-bootstrap: "+format+"\n", a...)
	os.Exit(1)
}

func main() {
	exe, err := os.Executable()
	if err == nil {
		exe, err = filepath.EvalSymlinks(exe)
	}
	if err != nil {
		fail("%v", err)
	}

	dir := filepath.Dir(exe)
	windows := runtime.GOOS == "windows"

	var prefix, script string
	var pathAdds []string
	if windows {
		// The exe sits in <prefix>\Library\bin.
		prefix = filepath.Dir(filepath.Dir(dir))
		script = filepath.Join(prefix, "Library", "share", "dots-bootstrap", "bootstrap.nu")
		pathAdds = []string{
			filepath.Join(prefix, "Library", "bin"),
			filepath.Join(prefix, "Scripts"),
			filepath.Join(prefix, "bin"),
			prefix,
		}
	} else {
		prefix = filepath.Dir(dir)
		script = filepath.Join(prefix, "share", "dots-bootstrap", "bootstrap.nu")
		pathAdds = []string{filepath.Join(prefix, "bin")}
	}

	if _, err := os.Stat(script); err != nil {
		fail("script not found at %s", script)
	}

	newPath := strings.Join(pathAdds, string(os.PathListSeparator))
	if old := os.Getenv("PATH"); old != "" {
		newPath += string(os.PathListSeparator) + old
	}
	if err := os.Setenv("PATH", newPath); err != nil {
		fail("%v", err)
	}

	nu, err := exec.LookPath("nu")
	if err != nil {
		fail("nu not found")
	}

	cmd := exec.Command(nu, append([]string{"--no-config-file", script}, os.Args[1:]...)...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		var ee *exec.ExitError
		if errors.As(err, &ee) {
			os.Exit(ee.ExitCode())
		}
		fail("%v", err)
	}
}
