# Template Variables and Secrets

Sensitive values are kept out of version control using templates and git-ignored files.

## Template System

Files ending in `.template` contain `{{PLACEHOLDER}}` variables:

```ini
# git/.gitconfig.template
[user]
    name = {{GIT_NAME}}
    email = {{GIT_EMAIL}}
```

## Setting Up

1. Copy the example:
   ```bash
   cp templates/variables.env.example variables.env
   ```

2. Fill in your values:
   ```bash
   GIT_NAME="Your Name"
   GIT_EMAIL="you@example.com"
   KEELVAR_KEY_PATH="~/.ssh/id_rsa_work"
   PERSONAL_KEY_PATH="~/.ssh/id_rsa_personal"
   PYTHON_VENV_PATH="~/venvs/.nvim-venv"
   ```

3. Run the installer (renders all templates):
   ```bash
   ./scripts/install.sh
   ```

## Template Variables

| Variable            | Used In              | Description                        |
|---------------------|----------------------|------------------------------------|
| `GIT_NAME`          | git/.gitconfig       | Name for git commits               |
| `GIT_EMAIL`         | git/.gitconfig       | Email for git commits              |
| `KEELVAR_KEY_PATH`  | ssh/.ssh/config      | Path to work SSH key               |
| `PERSONAL_KEY_PATH` | ssh/.ssh/config      | Path to personal SSH key           |
| `PYTHON_VENV_PATH`  | nvim/.config/nvim/   | Python venv for Neovim             |

## Security Rules

- `variables.env` is git-ignored. Never commit it.
- `machines/*/.env.zsh` files are git-ignored. They contain runtime secrets.
- `.template` files are committed. They only contain placeholder names.
- If you accidentally commit a secret, rotate it immediately.
