#!/usr/bin/env -S just --justfile
# Taken from https://github.com/onedr0p/home-ops/blob/main/.justfile

set lazy
set quiet
set shell := ['bash', '-euo', 'pipefail', '-c']

# Bootstrap Recipes
[group: 'Bootstrap']
mod bootstrap "bootstrap"

# Kube Recipes
[group: 'Kube']
mod kube "kubernetes"

# Talos Recipes
[group: 'Talos']
mod talos "talos"

[private]
default:
    just -l

[private]
log lvl msg *args:
    gum log -t rfc3339 -s -l "{{ lvl }}" "{{ msg }}" {{ args }}

[private]
template file *args:
    # cat to stdin: minijinja-cli 2.24.0 quotes -D define values when read from a file path in some environments; stdin is clean.
    cat "{{ file }}" | minijinja-cli {{ args }} | op inject
