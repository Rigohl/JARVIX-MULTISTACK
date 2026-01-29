# JARVIX Deployment (POC)

This doc shows a minimal POC flow using Supabase or Neon (Postgres) and Helm.

## Prereqs
- Kubernetes cluster (minikube / k3s / cloud)
- Helm 3
- Docker or registry to push images
- Supabase or Neon project (get DATABASE_URL)

## Build image (example)

```
./scripts/docker-build.sh latest
docker push <your-repo>/jarvix-engine:latest
```

## Install with Helm

```bash
helm install jarvix deploy/helm/jarvix \
  --set image.repository=<your-repo>/jarvix-engine \
  --set image.tag=latest \
  --set env.DB_URL="$DATABASE_URL" \
  --set env.SUPABASE_URL="$SUPABASE_URL" \
  --set env.SUPABASE_KEY="$SUPABASE_KEY"
```

## Migrate SQLite metrics to Postgres

```
# from repo root
bash scripts/migrate_sqlite_to_postgres.sh data/metrics.sqlite "$DATABASE_URL"
```

Notes:
- The migration script imports all columns as TEXT (POC). Review and apply proper types after migration.
- For Supabase: use the dashboard to get `DATABASE_URL`. For Neon: use console.
- For production consider proper backups, TLS and secrets in Kubernetes (use sealed-secrets or external secret stores).
