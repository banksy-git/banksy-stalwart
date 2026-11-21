# banksy-stalwart

Automated container builds of [Stalwart](https://github.com/stalwartlabs/stalwart)
compiled with only the `sqlite` and `s3` cargo features: no enterprise code, and no
RocksDB/Postgres/MySQL/Redis/NATS/Azure.

```sh
docker pull ghcr.io/<owner>/banksy-stalwart:latest
```

Images are multi-arch (`linux/amd64`, `linux/arm64`) and otherwise identical to
upstream's: same base image, entrypoint, volumes, ports and healthcheck.

## How it works

`.github/workflows/build.yml` runs every 6 hours:

1. **check**: asks the GitHub API for upstream's latest (non-pre-)release. If
   this repo already has a GitHub release of that tag, it stops.
2. **build**: checks out upstream at that tag, rewrites the `--features` list
   in upstream's own `Dockerfile` via `scripts/patch-dockerfile.sh`, and builds
   each architecture in parallel, pushing by digest. A registry build cache
   (`banksy-stalwart-buildcache:<arch>`) keeps the dependency layer between releases.
3. **publish**: combines the digests into one multi-arch manifest, tags it, and
   creates a matching GitHub release here (which is the "already built" marker).

Patching upstream's Dockerfile rather than keeping a copy means changes to the
base image, dependencies or runtime layout are picked up automatically. If
upstream restructures the file so the feature list can't be found, the patch
script fails the build instead of quietly shipping a default (enterprise) build.

### Tags

| Tag | Example | When |
|-----|---------|------|
| `vX.Y.Z`, `X.Y.Z` | `v1.1.1`, `1.1.1` | every build |
| `X.Y` | `1.1` | latest upstream release only |
| `latest` | `latest` | latest upstream release only |

### Manual runs

*Actions → Build Stalwart → Run workflow*:

- **version**: build a specific upstream tag (e.g. an older release or an RC).
- **force**: rebuild even if already released (e.g. to pick up base-image
  security updates). Tags are re-pointed; the GitHub release is left as is.

### Changing features

Edit `FEATURES` at the top of the workflow, then run it with **force**.

