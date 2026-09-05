#!/bin/bash
##############################################################################
# Script:  aws_resource_tracker.sh
# Purpose: Generates a report of current AWS resource usage:
#          S3 buckets, EC2 instances, Lambda functions, IAM users.
# Usage:   ./aws_resource_tracker.sh
# Cron:    0 8 * * * /home/hamza/scripts/aws_resource_tracker.sh
##############################################################################

set -uo pipefail

REPORT_DIR="/home/hamza/aws_reports"
DATE=$(date +%Y-%m-%d_%H-%M-%S)
REPORT_FILE="${REPORT_DIR}/resource_report_${DATE}.txt"
LOG_FILE="${REPORT_DIR}/tracker.log"

log() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1" | tee -a "$LOG_FILE"
}

ensure_report_dir() {
    mkdir -p "$REPORT_DIR"
}

check_prerequisites() {
    if ! command -v aws &>/dev/null; then
        log "ERROR: aws CLI is not installed"
        return 1
    fi

    if ! command -v jq &>/dev/null; then
        log "ERROR: jq is not installed (needed to parse AWS JSON output)"
        return 1
    fi

    if ! aws sts get-caller-identity &>/dev/null; then
        log "ERROR: AWS credentials are not configured or invalid"
        return 1
    fi

    log "OK: prerequisites verified"
    return 0
}

section() {
    {
        echo ""
        echo "===== $1 ====="
    } >> "$REPORT_FILE"
}

report_s3_buckets() {
    section "S3 Buckets"

    local buckets
    if ! buckets=$(aws s3 ls 2>>"$LOG_FILE"); then
        echo "ERROR: failed to list S3 buckets" >> "$REPORT_FILE"
        log "ERROR: aws s3 ls failed"
        return 1
    fi

    if [ -z "$buckets" ]; then
        echo "No S3 buckets found" >> "$REPORT_FILE"
    else
        echo "$buckets" >> "$REPORT_FILE"
    fi

    log "OK: S3 bucket list captured"
    return 0
}

report_ec2_instances() {
    section "EC2 Instances"

    local instances
    if ! instances=$(aws ec2 describe-instances \
        --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name]' \
        --output text 2>>"$LOG_FILE"); then
        echo "ERROR: failed to list EC2 instances" >> "$REPORT_FILE"
        log "ERROR: aws ec2 describe-instances failed"
        return 1
    fi

    if [ -z "$instances" ]; then
        echo "No EC2 instances found" >> "$REPORT_FILE"
    else
        printf "%-20s %-15s %-10s\n" "InstanceId" "Type" "State" >> "$REPORT_FILE"
        echo "$instances" | awk '{printf "%-20s %-15s %-10s\n", $1, $2, $3}' >> "$REPORT_FILE"
    fi

    log "OK: EC2 instance list captured"
    return 0
}

report_lambda_functions() {
    section "Lambda Functions"

    local functions
    if ! functions=$(aws lambda list-functions \
        --query 'Functions[*].[FunctionName,Runtime,LastModified]' \
        --output text 2>>"$LOG_FILE"); then
        echo "ERROR: failed to list Lambda functions" >> "$REPORT_FILE"
        log "ERROR: aws lambda list-functions failed"
        return 1
    fi

    if [ -z "$functions" ]; then
        echo "No Lambda functions found" >> "$REPORT_FILE"
    else
        echo "$functions" >> "$REPORT_FILE"
    fi

    log "OK: Lambda function list captured"
    return 0
}

report_iam_users() {
    section "IAM Users"

    local users
    if ! users=$(aws iam list-users \
        --query 'Users[*].[UserName,CreateDate]' \
        --output text 2>>"$LOG_FILE"); then
        echo "ERROR: failed to list IAM users" >> "$REPORT_FILE"
        log "ERROR: aws iam list-users failed"
        return 1
    fi

    if [ -z "$users" ]; then
        echo "No IAM users found" >> "$REPORT_FILE"
    else
        echo "$users" >> "$REPORT_FILE"
    fi

    log "OK: IAM user list captured"
    return 0
}

generate_report_header() {
    {
        echo "AWS Resource Report"
        echo "Generated: $(date +"%Y-%m-%d %H:%M:%S")"
        echo "Account: $(aws sts get-caller-identity --query Account --output text 2>/dev/null)"
    } > "$REPORT_FILE"
}

run_tracker() {
    log "===== AWS resource tracking started ====="
    ensure_report_dir

    check_prerequisites || return 1

    generate_report_header

    local issues=0
    report_s3_buckets      || issues=$((issues + 1))
    report_ec2_instances   || issues=$((issues + 1))
    report_lambda_functions || issues=$((issues + 1))
    report_iam_users       || issues=$((issues + 1))

    log "===== Tracking complete: $issues issue(s), report at $REPORT_FILE ====="
    [ "$issues" -eq 0 ]
}

main() {
    if run_tracker; then
        echo "Report generated: $REPORT_FILE"
        exit 0
    else
        echo "Report generated with some errors — check $LOG_FILE"
        exit 1
    fi
}

main "$@"