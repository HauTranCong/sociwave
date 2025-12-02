# Ruff: linting for the backend

Install dev requirements for the backend (recommended inside a virtualenv):

PowerShell:

```powershell
python -m venv .venv; .\.venv\Scripts\Activate.ps1; pip install -r requirements-dev.txt
```

Run ruff (check only):

```powershell
.\tools\check-ruff.ps1
```

Run ruff and auto-fix issues:

```powershell
.\tools\check-ruff.ps1 -Fix
```

If you prefer to install ruff globally:

```powershell
pip install ruff
ruff check backend
```
