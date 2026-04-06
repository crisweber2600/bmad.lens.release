# Lens Module Package

This package is prepared for BMAD custom module installation workflows.

## Contents

- module.yaml
- module-help.csv
- bmadconfig.yaml
- _module-installer/installer.js
- .claude-plugin/marketplace.json
- skills/bmad-lens-*/

## Install Flow

1. Make this package available to your BMAD installer source (git/npm/local path, depending on your environment).
2. Run bmad-method install for module code `lens`.
3. After install, run skill `bmad-lens-setup` once to merge config and register help entries.
