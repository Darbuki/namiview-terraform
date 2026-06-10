# ml — ephemeral GPU training rig (namiview#230)

Disposable layer for Nami v2 model training. Durable data (datasets, code
tarballs, checkpoints, run logs) lives in `s3://namiview-ml` — owned by
**foundation**, never by this layer. Destroying this layer loses nothing.

## How a training run works

1. Launcher packs the namiview repo's `ml/` into `s3://namiview-ml/code/run.tar.gz`
   and calls `run-instances` against the `namiview-ml-train` launch template
   (Phase 2 adds a GitHub Actions launcher; until then: AWS CLI from the MacBook).
2. The spot instance boots the Deep Learning Base AMI (driver + CUDA ready),
   pulls the tarball, runs `ml/train/entry.sh <bucket> <run-id>`.
3. Checkpoints/metrics sync to `s3://namiview-ml/runs/<run-id>/` (entry.sh's job;
   the boot log is uploaded by user-data regardless).
4. The instance powers off → spot one-time + terminate-on-shutdown = gone.
   A `shutdown -h +N` watchdog (default 8h) bounds even a hung run.

## Cost

- Idle: $0 (a launch template and empty network are free; bucket pennies/mo).
- Per run: g4dn.xlarge spot ≈ $0.20/h → typical run $0.50–$2.
- Debug shell: SSM Session Manager (no SSH, no inbound ports).

## Knobs (variables.tf)

`instance_type` (default g4dn.xlarge), `az` (flip on spot capacity errors),
`root_volume_gb` (100), `max_run_minutes` (480).
