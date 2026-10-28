# Gym Attendance and Membership Management

Private management app for the owner and authorized staff, plus a public
entrance check-in page for members and walk-ins. The app is a React + Vite +
TypeScript PWA foundation. Supabase will provide PostgreSQL, Auth, Row Level
Security, and Realtime where appropriate after the data and access design is
approved.

## Local development

Requirements: Node.js and npm. On Windows PowerShell, use `npm.cmd` if the
execution policy blocks `npm.ps1`.

```powershell
npm.cmd install
Copy-Item .env.example .env.local
npm.cmd run dev
```

After copying the example, open `.env.local` and fill in these two values:

- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_PUBLISHABLE_KEY`

To get them, open your project in the Supabase Dashboard and use the **Connect**
dialog, or open **Project Settings > API Keys**. Copy the Project URL and the
publishable key into `.env.local` locally; do not paste credentials into chat.
The publishable key is intended for browser clients. Never use a secret or
service-role key in this app. Keep Row Level Security enabled and use policies
to control data access before exposing database operations.

The typed client helper is lazy: the landing page remains usable without local
configuration, while calling `getSupabaseClient()` without a valid URL and
publishable key throws a clear `SupabaseConfigurationError`. Restart the Vite
development server after changing `.env.local`. This foundation does not yet
connect to tables or configure authentication workflows.

`.env.local` and other `.env.*` files are ignored by Git. `.env.example` must
contain placeholders only. Do not commit environment files or credentials.

## Checks

```powershell
npm.cmd run lint
npm.cmd run typecheck
npm.cmd run build
```

See [AGENTS.md](AGENTS.md) for the approved requirements, security rules,
prohibited features, and development workflow.
