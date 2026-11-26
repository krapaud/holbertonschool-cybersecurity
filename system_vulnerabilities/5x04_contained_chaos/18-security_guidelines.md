# DevStream Container Security Guidelines

## Purpose and Scope

These guidelines apply to container images and workloads built or operated by
the DevStream development team. They establish a practical baseline for
development, testing, and production deployments. A project may add stricter
controls when its data or threat model requires them.

## 1. Dockerfile Rules

### Required practices

- Use a small, maintained base image and pin it to an explicit version. Pin
  production images by digest when the release process supports it.
- Use multi-stage builds when build tools or compilers are needed. Keep
  compilers, package managers' caches, and test-only dependencies out of the
  runtime stage.
- Install only packages required for the image's purpose. Use
  `--no-install-recommends` where supported and remove package indexes and
  temporary build files in the same build step.
- Run the application as a dedicated non-root user. Set ownership and file
  permissions explicitly, and use `WORKDIR` to make file locations clear.
- Add OCI labels for the image title, description, version, and owner or
  vendor. Add a `HEALTHCHECK` when the application has a reliable health
  endpoint or health command.
- Copy only required application files. Use `.dockerignore` to exclude local
  virtual environments, caches, credentials, version-control metadata, and
  unrelated files.
- Keep dependency manifests under version control and pin or lock dependency
  versions for reproducible builds.

### Prohibited practices

- Never put passwords, API keys, private keys, tokens, or other credentials in
  `ARG`, `ENV`, `RUN`, labels, build logs, or copied files. Build arguments and
  image layers can be inspected.
- Do not use `latest` for a release base image, run the application as root,
  install unnecessary diagnostic or development tools in production, or use
  `sudo` inside an application image.
- Do not use privileged containers to work around a missing permission. Do
  not copy the Docker socket into an application container.
- Do not use `ADD` for ordinary local files; prefer `COPY`. If remote content
  must be downloaded, verify its source and checksum.

## 2. Base Image Policy

- Approved starting points for Python workloads are the official
  `python:3.11-slim` image used by this lab and other official or organization-
  approved minimal images with an active security update channel.
- Select the smallest maintained image that supports the application. Alpine
  or distroless images may be used only after compatibility and operational
  requirements have been reviewed.
- Pin the Python minor version and use a digest for production release builds
  where feasible. Record the selected image and digest in the build or release
  metadata.
- Review upstream security notices and rebuild at least monthly, and sooner
  when a relevant critical or high-severity vulnerability is announced.
- Scan the base image and final image before release. Upgrade or replace images
  that are end-of-life or no longer receive security updates.

## 3. Secret Management

- Keep secrets out of the repository, Dockerfiles, image layers, build
  arguments, and plain-text logs.
- For local development, use an approved local secret file excluded by
  `.gitignore`, or a developer secret manager. Do not commit example files
  containing working credentials.
- In CI and production, obtain secrets from the approved secret manager or
  platform secret store and provide them at runtime. Prefer mounted secret
  files when the application supports them; restrict file ownership and
  permissions to the service account.
- Grant each workload only the secrets it needs. Rotate a credential promptly
  if it may have been exposed, and record the rotation in the incident or
  change record.
- Treat environment variables as runtime injection rather than image content;
  avoid printing them and restrict access to container metadata and process
  inspection.

## 4. Runtime Requirements

Production containers must meet these baseline requirements unless an
approved exception is recorded:

- Run as a non-root user with only the filesystem access required by the
  application.
- Drop all Linux capabilities with `--cap-drop=ALL`; add a capability only
  when the application owner documents its need and security approves it.
- Set `no-new-privileges:true` and retain the platform's default seccomp
  profile. Do not disable AppArmor or SELinux enforcement.
- Use a read-only root filesystem. Provide narrowly scoped writable `tmpfs` or
  volumes only for documented application data, with `noexec`, `nosuid`, and
  `nodev` where compatible.
- Set memory, CPU, and process-count limits appropriate to the workload.
- Do not use host networking, host PID namespace, privileged mode, or broad
  host mounts unless an approved exception requires them.
- Configure health checks, restart behavior, log collection, and monitoring in
  the deployment platform. Keep the image free of secrets and host-specific
  configuration.
- Pin the image used for production deployment to an immutable tag or digest.

The Compose service in this lab is a development example. Production
deployments must apply equivalent controls using the organization-approved
orchestrator and must be reviewed against the workload's needs.

## 5. Audit Requirements

- Scan every image in CI before publishing it and retain the scan result with
  the build artifact. Block release for known critical vulnerabilities unless
  an exception is approved.
- Run Docker Bench Security or the organization's approved CIS Docker
  Benchmark tooling when establishing a host baseline, after significant
  Docker or host configuration changes, and at least quarterly.
- Review Dockerfile changes and runtime configuration during code review.
  Verify the configured user, exposed ports, writable paths, capabilities,
  privilege settings, resource limits, health check, and secret handling.
- Record the image digest, scan date, findings, and remediation owner. Re-scan
  after rebuilding or changing the base image.
- Treat benchmark output as evidence for the tested host and image inventory;
  do not attribute a host-wide score to a single image without an isolated
  test or tool output that identifies that image.

## 6. Exception Process

1. The service owner submits a written request before deployment, identifying
   the exact rule, image digest or workload, and the operational need.
2. The request describes the security impact, affected data and systems,
   compensating controls, and why a compliant alternative is not practical.
3. The security owner and the service owner approve the request. High-impact
   exceptions also require the designated security leadership approval.
4. Each exception names an accountable owner, an expiration date, and a review
   date. Exceptions are time-limited and must be renewed with updated evidence.
5. The approval and related risk acceptance are recorded in the change or risk
   register. Remove the exception when the underlying need ends.

An exception does not waive incident reporting, vulnerability remediation, or
secret rotation requirements.
