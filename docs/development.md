# Development

All requirements for bootstrapping, docs and development can be installed from the single `requirements.txt` file. All assisting infrastructure is Python-based. Install with

```bash
pip install -r requirements.txt
```

## Pre-commit

As a precaution against accidental secret leaks, a [gitleaks](https://github.com/gitleaks/gitleaks) pre-commit hook is provided. [Pre-commit](https://pre-commit.com/) will be installed when you install from `requirements.txt`.

Continue the first-time setup for the hooks with the following:

```bash
pre-commit autoupdate  # update the pre-commit hook versions
pre-commit install  # install the hooks
```

The gitleaks hook will scan staged, but not yet committed, files for secrets. The commit will fail if it finds a leaked secret that you are inadvertently trying to commit.

To modify either the pre-commit hook or gitleaks, see their respective documentation.


## Publishing the docs

The documents are built using [Material for Mkdocs](https://squidfunk.github.io/mkdocs-material/).

To preview the docs as you edit:

```bash
mkdocs serve
```

To check the build:

```bash
mkdocs build --strict
```

The docs are published to GitHub pages with GitHub Actions.

## Updating the changelog

The Changelog is maintained with [scriv](https://scriv.readthedocs.io/).

Add a changelog fragment with every fix, change, feature addition etc:

```bash
scriv create
```

The fragment will go to the `changelog.d` directory and you can edit it there.

Upon release, set the desired version number in `changelog.d/scriv.ini` and compile the fragments into the next version:

```bash
scriv collect
```

The fragments will be added to the `CHANGELOG.md` file in the root directory. It can then be cleaned up manually before committing. 

## Github Actions

Two actions are pre-configured:

- Auto-update pre-commit hook versions
- Build the docs and publish to GitHub Pages 