# Deployment gate

No public application deployment is claimed for v1.0.0.

The repository retains two manual blueprints:

- `.github/workflows/deploy-web.yml` builds the Flutter static client only when manually dispatched and `FRONTEND_API_BASE_URL` is configured.
- `render.yaml` defines the Flask service with automatic deployment disabled and persistence off.

Before any public launch, the owner must:

1. rotate the historical MySQL credential if it was ever used and restrict/rotate the two historical Google API keys;
2. decide whether the service is a non-persistent synthetic demo or an authenticated application;
3. add authentication, tenant isolation, retention controls, privacy review, and abuse protection for any retained records;
4. set a strong `SECRET_KEY`, exact `CORS_ORIGINS`, and provider-managed TLS;
5. verify backend and frontend URLs, then rerun the full browser workflow against the hosted build.

The current configuration intentionally avoids turning a portfolio prototype into an unauthenticated public health-data store.
