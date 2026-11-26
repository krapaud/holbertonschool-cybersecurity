# Secure Python Development Environment

## Purpose

This design provides a small and practical container for developing and
testing the DevStream Flask application. The container should reduce the
impact of mistakes or a compromised process while keeping the usual Python
development workflow available.

## 1. Base Image Selection

Use the official `python:3.11-slim` image. It includes the required Python
runtime without the large set of packages found in a full Ubuntu image. The
version is pinned to the Python minor release so a rebuild does not silently
move to a different Python version. The build uses separate stages so
compilers and other build-only packages do not enter the final runtime image.

## 2. Included Tools

The runtime image contains the application and its pinned runtime dependencies
from `requirements.txt`, including Flask. Development-only tools are installed
from a separate `requirements-dev.txt` in the development image:

- `pytest` for automated tests
- `ruff` for linting and basic formatting
- `black` for consistent Python formatting

These tools are not copied into a production image. Dependency versions are
kept in requirements files so developers can reproduce the same environment.

## 3. User Configuration

The image creates an unprivileged account named `appuser` with UID and GID
1000. The application and its required files are readable by this account, and
the container starts as `appuser`. It does not need `sudo` or root access.
Any writable application data is assigned to this account explicitly.

## 4. Volume Strategy

Developers edit source code on the host and bind-mount the project directory
into `/workspace` in the development container. The mount is read-only by
default: edits happen in the host editor, while the container can run tests and
linters without changing the checked-out source. If a tool needs temporary
output, use `/tmp` or a dedicated output directory rather than making the
whole container filesystem writable.

Python dependencies are installed in the image during build, not into the
host's Python installation. Test caches and temporary files belong in
container-local temporary storage or a separate disposable volume.

## 5. Security Measures

The development container applies these controls:

- Build from the official slim Python image with a multi-stage build.
- Run as `appuser`, never as root.
- Do not place credentials in the Dockerfile, image layers, or source control.
  Supply secrets at runtime, preferably through a secret file or secret
  manager.
- Drop all Linux capabilities with `--cap-drop=ALL`; add one back only if a
  documented application requirement exists.
- Use `--read-only` for the root filesystem, with limited `tmpfs` mounts for
  `/tmp` and `/app/logs` when those paths are needed.
- Set `no-new-privileges` and retain Docker's default seccomp filtering.
- Set memory, CPU, and PID limits to reduce resource exhaustion.
- Define a health check for the application's `/health` endpoint.
- Keep the source bind mount read-only and avoid mounting the Docker socket.

These settings are applied at container run time and are reviewed alongside
the Dockerfile. Development convenience does not require privileged mode.

## 6. Developer Experience

The developer workflow is to build the image, start the container with the
project mounted at `/workspace`, and run the app, tests, or code checks inside
that environment. The host editor remains the normal place to change files.
The `pytest`, `ruff`, and `black` commands are available in the development
image, while the smaller runtime image contains only the application needs.

Example workflow using the planned `Dockerfile.dev` and
`requirements-dev.txt` files:

```sh
docker build -t devstream-dev:latest -f Dockerfile.dev .
docker run --rm --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,nodev,size=64m \
  --tmpfs /app/logs:rw,noexec,nosuid,nodev,size=32m \
  --cap-drop=ALL \
  --security-opt=no-new-privileges:true \
  --memory=512m --memory-swap=512m --cpus=1 --pids-limit=100 \
  --mount type=bind,src="$PWD",dst=/workspace,readonly \
  devstream-dev:latest pytest
```

Secrets are supplied separately at run time and are never committed with the
project. The image can be rebuilt from the requirements files when dependencies
change.
