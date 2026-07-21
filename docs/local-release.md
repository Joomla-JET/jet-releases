# Local release process

The Joomla update site is published from the `gh-pages` branch at:

    https://joomla-jet.github.io/jet-releases

## Prepare the sources

Commit and push the extension changes in its own repository. Increment the
`<version>` in its Joomla manifest, then update and commit the submodule pointer
in `jet-dev`.

Initialize the pinned sources after cloning `jet-dev`:

```bash
git submodule update --init --recursive
```

## Build and verify

Build and verify every extension:

```bash
make build
make verify
```

Build and verify only one extension:

```bash
make build EXTENSION=mod_jet_map
make verify EXTENSION=mod_jet_map
```

`BASE_URL` defaults to `https://joomla-jet.github.io/jet-releases`. It can be
overridden for a staging update site:

```bash
make build BASE_URL=https://staging.example.org
```

Artifacts are written below `build/releases/`, which is intentionally ignored
by Git.

## Publish to GitHub Pages

Preview a publication without contacting GitHub:

```bash
make publish-dry-run
make publish-dry-run EXTENSION=mod_jet_map
```

Publish all built extensions or one selected extension:

```bash
make publish
make publish EXTENSION=mod_jet_map
```

Build, verify, and publish in one command:

```bash
make release
make release EXTENSION=mod_jet_map
```

The command verifies the artifacts again, updates the `gh-pages` branch in a
temporary Git worktree, commits, and pushes it. Previously published packages
are retained. An existing versioned package cannot be replaced with different
bytes: increment the manifest version and rebuild instead.

The remote and branch can be overridden with `PAGES_REMOTE` and
`PAGES_BRANCH`. After the first publication, configure GitHub Pages to deploy
from the root of the `gh-pages` branch.
