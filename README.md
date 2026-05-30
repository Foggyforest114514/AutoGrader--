# AutoGrader Submodule Workflow

This repository uses Git submodules for the B1, B2, B3, and B4 projects.

## Clone the Repository

Use `--recurse-submodules` when cloning so Git also checks out the submodule
repositories:

```bash
git clone --recurse-submodules <repo-url>
# TEST PR
```

If you already cloned the repository without submodules, initialize them with:

```bash
git submodule update --init --recursive
```

## Local Setup and Startup

Prepare each module according to its own README before starting everything:

```bash
# B1
cd B1
npm install

# B2
cd ../B2
python3 -m venv .venv
source .venv/bin/activate
pip install fastapi "uvicorn[standard]" httpx pydantic
deactivate

# B3
cd ../B3
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
deactivate

# B4
cd ../B4/autograder_api
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
deactivate
```

Then start all modules from the repository root:

```bash
./start_all.sh
```

The startup script only starts services. It does not install dependencies or
create virtual environments. Logs are written to `logs/`.

Default local URLs:

```text
B1 frontend: http://127.0.0.1:5173
B2 service:  http://127.0.0.1:8002/docs
B3 service:  http://127.0.0.1:8003/docs
B4 API:      http://127.0.0.1:8000/docs
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

## After Pulling Changes

After pulling updates from the main repository, sync your local submodule
working trees:

```bash
git submodule update --init --recursive
```

If a merged pull request updated submodule pointers, this command moves your
local submodule checkouts to the commits recorded by the main repository.
