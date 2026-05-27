# AutoGrader Submodule Workflow

This repository uses Git submodules for the B1, B2, B3, and B4 projects.

## Clone the Repository

Use `--recurse-submodules` when cloning so Git also checks out the submodule
repositories:

```bash
git clone --recurse-submodules <repo-url>
```

If you already cloned the repository without submodules, initialize them with:

```bash
git submodule update --init --recursive
```

## How Submodules Work Here

Each submodule is pinned by the main repository to a specific commit. Even
though each submodule is configured to track its `main` branch, a normal clone
checks out the commit recorded by this repository.

The tracked branches are configured in `.gitmodules`:

```ini
[submodule "B1"]
    branch = main
[submodule "B2"]
    branch = main
[submodule "B3"]
    branch = main
[submodule "B4"]
    branch = main
```

Seeing a detached `HEAD` inside a submodule is normal. It means the submodule is
checked out at the exact commit recorded by the main repository.

## Update Submodules Manually

To update all submodules to the latest commit on their configured `main`
branches:

```bash
git submodule update --remote --merge --recursive
```

Then commit the updated submodule pointers in the main repository:

```bash
git add B1 B2 B3 B4
git commit -m "Update submodules"
```

This commit is required so everyone else receives the same submodule versions
after pulling the main repository.

## Dependabot Updates

Dependabot is configured to check git submodules hourly:

```yaml
version: 2
updates:
  - package-ecosystem: "gitsubmodule"
    directory: "/"
    schedule:
      interval: "hourly"
```

When a submodule has a newer commit available, Dependabot should open a pull
request that updates the recorded submodule pointer. Review and merge that pull
request like any other dependency update.

## After Pulling Changes

After pulling updates from the main repository, sync your local submodule
working trees:

```bash
git submodule update --init --recursive
```

If a merged pull request updated submodule pointers, this command moves your
local submodule checkouts to the commits recorded by the main repository.
