# Template System

Template files use `{{PLACEHOLDER}}` syntax for values that vary per machine or contain secrets.

## How It Works

1. Template files end in `.template` (e.g., `git/.gitconfig.template`)
2. Actual values are stored in `variables.env` (git-ignored)
3. Running `./scripts/install.sh` reads `variables.env` and substitutes placeholders

## Setup

```bash
cp variables.env.example variables.env
# Edit variables.env with your values
./scripts/install.sh
```

## Variables

- `GIT_NAME` - Name for git commits
- `GIT_EMAIL` - Email for git commits
- `KEELVAR_KEY_PATH` - Path to work SSH key
- `PERSONAL_KEY_PATH` - Path to personal SSH key
- `PYTHON_VENV_PATH` - Python virtual environment base directory

See [docs/SECRETS.md](../docs/SECRETS.md) for the full guide.
