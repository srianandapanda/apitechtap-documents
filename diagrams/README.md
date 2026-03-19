# Architecture diagrams (PNG + source)

PNG images are **rendered snapshots** so diagrams stay visible in any Markdown viewer (GitHub, VS Code, PDF export).

| PNG | Source `.mmd` |
|-----|----------------|
| `png/hld-system-context.png` | `source/hld-system-context.mmd` |
| `png/hld-layered.png` | `source/hld-layered.mmd` |
| `png/hld-kubernetes.png` | `source/hld-kubernetes.mmd` |
| `png/seq-signup.png` | `source/seq-signup.mmd` |
| `png/seq-login-jwt.png` | `source/seq-login-jwt.mmd` |
| `png/seq-authenticated-overview.png` | `source/seq-authenticated-overview.mmd` |
| `png/seq-resume-s3.png` | `source/seq-resume-s3.mmd` |
| `png/seq-payment-webhook.png` | `source/seq-payment-webhook.mmd` |
| `png/seq-admin-plan.png` | `source/seq-admin-plan.mmd` |
| `png/seq-all-services-unified.png` | `source/seq-all-services-unified.mmd` |

## Regenerate PNGs (PowerShell, uses [Kroki](https://kroki.io))

From **repository root**:

```powershell
New-Item -ItemType Directory -Force -Path "docs/diagrams/png" | Out-Null
Get-ChildItem "docs/diagrams/source/*.mmd" | ForEach-Object {
  $bytes = [System.Text.Encoding]::UTF8.GetBytes([System.IO.File]::ReadAllText($_.FullName))
  $out = Join-Path "docs/diagrams/png" ($_.BaseName + ".png")
  Invoke-WebRequest -Uri "https://kroki.io/mermaid/png" -Method POST -Body $bytes `
    -ContentType "text/plain; charset=utf-8" -OutFile $out -UseBasicParsing
}
```

Or with **Mermaid CLI** (Node.js), from repo root:

```bash
npx @mermaid-js/mermaid-cli -i docs/diagrams/source/FILE.mmd -o docs/diagrams/png/FILE.png
```

After editing a `.mmd` file, regenerate the matching `.png` and commit both.

**Master HLD with all images:** [../ARCHITECTURE-HLD.md](../ARCHITECTURE-HLD.md)
