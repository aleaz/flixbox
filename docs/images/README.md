# Documentation images

Screenshots and diagrams for the user guide.

## Layout (i18n-ready)

```text
docs/images/
├── README.md          ← this file
├── shared/            ← language-neutral diagrams (data layout, pipeline)
├── en/                ← English UI screenshots (canonical guide)
└── es/                ← Spanish UI screenshots (future docs/es/user/)
```

Do **not** put English-only UI shots in `shared/`.  
Do **not** embed secrets, API keys, or personal media titles in screenshots.

## Naming

Use stable kebab-case names referenced from markdown:

- `shared/data-layout.png`
- `en/prowlarr-byparr-proxy.png`
- `es/prowlarr-byparr-proxy.png` (same basename when translating)

## Markdown usage

```markdown
![Prowlarr Byparr proxy](../images/en/prowlarr-byparr-proxy.png)
```

Spanish pages will use `../images/es/...` (path relative to `docs/es/user/`).

## When to add screenshots

Prefer after the stack boots successfully. Priority list is in the user guide first-run doc.
