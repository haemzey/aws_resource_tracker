# AWS Resource Tracker

A shell script that generates a timestamped report of AWS resource usage across an account — S3 buckets, EC2 instances, Lambda functions, and IAM users. Built for scheduled, unattended execution (cron) with proper error handling and logging.

## What it does

The script queries four AWS services and writes the results into a single, human-readable report file:

| Resource | Details captured |
|---|---|
| S3 Buckets | Bucket names |
| EC2 Instances | Instance ID, instance type, current state |
| Lambda Functions | Function name, runtime, last modified date |
| IAM Users | Username, account creation date |

Each section runs independently — if one AWS service call fails (e.g. due to a permissions issue), the script still completes the remaining sections and produces a partial report, rather than stopping entirely.

## Requirements

- **AWS CLI v2** — installed and available on `$PATH`
- **jq** — used for JSON parsing (`sudo apt install jq` on Ubuntu/Debian)
- **Valid AWS credentials** — configured via `aws configure`, an IAM role, or environment variables, with at least read-only permissions for S3, EC2, Lambda, and IAM

The script verifies all three of these automatically before running and exits early with a clear error if any are missing.

## Installation

```bash
chmod +x aws_resource_tracker.sh
```

## Usage

Run manually:

```bash
./aws_resource_tracker.sh
```

Output on success:

```
Report generated: /home/hamza/aws_reports/resource_report_2026-09-05_08-00-00.txt
```

## Output files

| File | Purpose |
|---|---|
| `~/aws_reports/resource_report_<timestamp>.txt` | The actual resource report — a new file is created on every run, so historical reports are preserved |
| `~/aws_reports/tracker.log` | Execution log — records what succeeded, what failed, and when, across all runs |

### Example report structure

```
AWS Resource Report
Generated: 2026-09-05 08:00:00
Account: 123456789012

===== S3 Buckets =====
my-app-backups
my-app-static-assets

===== EC2 Instances =====
InstanceId           Type            State
i-0123456789abcdef0  t2.micro        running

===== Lambda Functions =====
process-orders   python3.12   2026-08-20T10:15:00.000+0000

===== IAM Users =====
alice   2025-11-02T09:00:00+00:00
```

## Scheduling with cron

To run automatically every day at 8 AM:

```bash
crontab -e
```

Add:

```
0 8 * * * /home/hamza/scripts/aws_resource_tracker.sh
```

Since cron runs with a minimal environment, use the **full path** to the script, and confirm `aws` and `jq` are reachable from cron's `PATH` (test with `which aws` and `which jq`, and hardcode those paths in the script if needed).

## Configuration

Edit these variables near the top of the script to change behavior:

| Variable | Default | Purpose |
|---|---|---|
| `REPORT_DIR` | `/home/hamza/aws_reports` | Where reports and the log file are stored |

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Report generated successfully, no errors |
| `1` | One or more sections failed, or a prerequisite check failed — check `tracker.log` for details |

## Error handling design

- Uses `set -uo pipefail` — catches unset variables and pipeline failures, without using `set -e`, so a single failed AWS call doesn't abort the entire script
- Each resource section (`report_s3_buckets`, `report_ec2_instances`, etc.) checks its own AWS CLI call and logs success or failure independently
- Prerequisites (CLI tools, credentials) are verified once, up front, before any report content is generated

## Version History

| Version | Date | Notes |
|---|---|---|
| v1 | 2026-09-05 | Initial release — S3, EC2, Lambda, IAM reporting with per-section error handling and logging |

## Roadmap / possible next steps

- Add automatic rotation of old report files (e.g. delete reports older than 30 days)
- Add a cost-estimate section using AWS Cost Explorer
- Add Slack/email notification on failure
