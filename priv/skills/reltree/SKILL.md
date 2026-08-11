---
name: reltree
description: Install the repository-provided reltree skill for local use with the Rebar3 plugin.
---

# Reltree

Use the target repository's current local facts and explicit user instructions. Do not substitute historical project lists or a fixed topology for the generated project tree.

## First install

Run `reltree` with no arguments to install this packaged skill locally. The optional `--dest DIR`
and `--force` flags select a skills parent directory and intentionally replace an existing
installation. Installation uses only the two packaged skill files and does not access the network.
