#!/bin/sh
#
# checking that try works when mergerfs/unionfs are not present (but also not necessary)

TRY_TOP="${TRY_TOP:-$(git rev-parse --show-toplevel --show-superproject-working-tree 2>/dev/null || echo "${0%/*}")}"
TRY="$TRY_TOP/try"

cleanup() {
    cd /

    if [ -d "$try_workspace" ]
    then
        rm -rf "$try_workspace" >/dev/null 2>&1
    fi

    if [ -d "$new_bin_dir" ]
    then
        rm -rf "$new_bin_dir"
    fi
}

trap 'cleanup' EXIT

run_regular() {
    new_bin_dir="$(mktemp -d)"
    mkdir "$new_bin_dir/usr"
    # -s makes symlinks
    cp -rs /usr/bin "$new_bin_dir/usr/bin"

    # Delete mergerfs and unionfs and set the new PATH to the temporary directory
    rm -f "$new_bin_dir/usr/bin/mergerfs" 2>/dev/null
    rm -f "$new_bin_dir/usr/bin/unionfs" 2>/dev/null

    echo hi >expected
    PATH="$new_bin_dir/usr/bin" "$TRY" -y "echo hi" >target 2>/dev/null || exit 1
    diff -q expected target || exit 2
}

run_nix() {
    cat > shell.nix <<'EOF'
    { pkgs ? import <nixpkgs> {} }:
    pkgs.mkShell {
        buildInputs = with pkgs; [
            attr
        ];
    }
EOF

    echo hi >expected
    # Run the command in a nix-shell with only the specified packages
    nix-shell --pure shell.nix --run "\"$TRY\" -y \"echo hi\"" >target 2>/dev/null || exit 3
    diff -q expected target || exit 4
}

# particularly important that we run in mktemp: in some test machines,
# the cwd is mounted, hence inaccessable.
try_workspace="$(mktemp -d)"
cd "$try_workspace" || exit 9

if [ -e /etc/NIXOS ]
then
    run_nix
else
    run_regular
fi
