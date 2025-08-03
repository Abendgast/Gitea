#!/bin/bash
set -euo pipefail

readonly GITEA_BIN="/usr/local/bin/gitea"
readonly GITEA_CONFIG="/data/gitea/conf/app.ini"
readonly GITEA_USER="git"
readonly GITEA_PORT="3000"
readonly ADMIN_CREATED_FLAG="/data/gitea/admin_created"
readonly MAX_STARTUP_WAIT=60
readonly MAX_SHUTDOWN_WAIT=30

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" >&2
}

log_success() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ $*"
}

cleanup() {
    local exit_code=$?
    log "Cleanup triggered with exit code: $exit_code"

    if [[ -n "${GITEA_PID:-}" ]] && kill -0 "$GITEA_PID" 2>/dev/null; then
        log "Stopping Gitea process (PID: $GITEA_PID)..."
        kill -TERM "$GITEA_PID" 2>/dev/null || true

        local count=0
        while kill -0 "$GITEA_PID" 2>/dev/null && [[ $count -lt $MAX_SHUTDOWN_WAIT ]]; do
            sleep 1
            ((count++))
        done

        if kill -0 "$GITEA_PID" 2>/dev/null; then
            log "Force killing Gitea process..."
            kill -KILL "$GITEA_PID" 2>/dev/null || true
        fi
    fi

    exit $exit_code
}

trap cleanup EXIT INT TERM

validate_env() {
    log "Validating environment variables..."

    local required_vars=(
        "GITEA__database__HOST"
        "GITEA__database__USER"
        "GITEA__database__NAME"
        "GITEA__database__PASSWD"
        "GITEA_ADMIN_USERNAME"
        "GITEA_ADMIN_PASSWORD"
        "GITEA_ADMIN_EMAIL"
        "GITEA__security__SECRET_KEY"
    )

    local missing_vars=()
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
        fi
    done

    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Missing required environment variables:"
        printf '  - %s\n' "${missing_vars[@]}"
        return 1
    fi

    log "Admin username: '$GITEA_ADMIN_USERNAME'"
    log "Admin email: '$GITEA_ADMIN_EMAIL'"
    log "Admin password length: ${#GITEA_ADMIN_PASSWORD}"
    log "Database host: '$GITEA__database__HOST'"

    log_success "Environment validation passed"
}

wait_for_database() {
    log "Waiting for database connection..."

    local db_host_only="${GITEA__database__HOST%%:*}"
    local db_port="${GITEA__database__HOST#*:}"
    [[ "$db_port" == "$GITEA__database__HOST" ]] && db_port="5432"

    local count=0
    while ! pg_isready -h "$db_host_only" -p "$db_port" -U "$GITEA__database__USER" -q; do
        if [[ $count -ge 30 ]]; then
            log_error "Database connection timeout after 60 seconds"
            return 1
        fi
        sleep 2
        ((count++))
    done

    log_success "Database is ready"
}

setup_directories() {
    log "Setting up directories and permissions..."

    local dirs=(
        "/data/gitea/conf"
        "/data/gitea/log"
        "/data/gitea/indexers"
        "/data/gitea/sessions"
        "/data/gitea/tmp"
        "/data/gitea/data"
        "/data/git/.ssh"
    )

    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
    done

    chown -R "$GITEA_USER:$GITEA_USER" /data
    chmod -R 755 /data
    chmod 700 /data/git/.ssh

    log_success "Directories and permissions set"
}

create_config() {
    log "Creating Gitea configuration..."

    cat > "$GITEA_CONFIG" <<CONFIG
[database]
DB_TYPE = postgres
HOST = ${GITEA__database__HOST}
NAME = ${GITEA__database__NAME}
USER = ${GITEA__database__USER}
PASSWD = ${GITEA__database__PASSWD}
SSL_MODE = require
LOG_SQL = false

[server]
HTTP_PORT = ${GITEA_PORT}
HTTP_ADDR = 0.0.0.0
DISABLE_SSH = true
START_SSH_SERVER = false

[service]
DISABLE_REGISTRATION = true

[security]
SECRET_KEY = ${GITEA__security__SECRET_KEY}
INSTALL_LOCK = true

[metrics]
ENABLED = true
TOKEN = gitea_metrics_token_2024
ENABLED_ISSUE_BY_LABEL = true
ENABLED_ISSUE_BY_REPOSITORY = true

[log]
MODE = console
LEVEL = Info
ROOT_PATH = /data/gitea/log

[session]
PROVIDER = file
PROVIDER_CONFIG = /data/gitea/sessions

[indexer]
REPO_INDEXER_ENABLED = true
REPO_INDEXER_PATH = /data/gitea/indexers/repos.bleve
MAX_FILE_SIZE = 1048576

[cache]
ENABLED = true
ADAPTER = memory

[queue]
TYPE = level
DATADIR = /data/gitea/queues
CONFIG

    chown "$GITEA_USER:$GITEA_USER" "$GITEA_CONFIG"
    chmod 600 "$GITEA_CONFIG"

    log_success "Configuration created with metrics enabled"
}

wait_for_gitea() {
    log "Waiting for Gitea to be ready..."

    local count=0
    while [[ $count -lt $MAX_STARTUP_WAIT ]]; do
        if curl -sf "http://localhost:$GITEA_PORT/api/v1/version" >/dev/null 2>&1; then
            log_success "Gitea is ready"
            return 0
        fi
        sleep 1
        ((count++))
    done

    log_error "Gitea failed to start within $MAX_STARTUP_WAIT seconds"
    return 1
}

manage_admin_user() {
    log "Managing admin user '$GITEA_ADMIN_USERNAME'..."

    # Try to create admin user
    local create_output
    if create_output=$(su-exec "$GITEA_USER" "$GITEA_BIN" admin user create \
        --username "$GITEA_ADMIN_USERNAME" \
        --password "$GITEA_ADMIN_PASSWORD" \
        --email "$GITEA_ADMIN_EMAIL" \
        --admin \
        --config "$GITEA_CONFIG" 2>&1); then

        log_success "Admin user '$GITEA_ADMIN_USERNAME' created successfully"
        return 0
    fi

    if echo "$create_output" | grep -iq "already exists\|user already exists"; then
        log "User already exists. Updating password and admin status..."

        if su-exec "$GITEA_USER" "$GITEA_BIN" admin user change-password \
            --username "$GITEA_ADMIN_USERNAME" \
            --password "$GITEA_ADMIN_PASSWORD" \
            --config "$GITEA_CONFIG" >/dev/null 2>&1; then

            log_success "Password updated for user '$GITEA_ADMIN_USERNAME'"
        else
            log_error "Failed to update password"
        fi

        if su-exec "$GITEA_USER" "$GITEA_BIN" admin user set-admin \
            --username "$GITEA_ADMIN_USERNAME" \
            --config "$GITEA_CONFIG" >/dev/null 2>&1; then

            log_success "Admin status set for user '$GITEA_ADMIN_USERNAME'"
        else
            log_error "Failed to set admin status"
        fi

        return 0
    fi

    log_error "Failed to create admin user: $create_output"
    return 1
}

verify_admin_user() {
    log "Verifying admin user..."

    if su-exec "$GITEA_USER" "$GITEA_BIN" admin user list --config "$GITEA_CONFIG" 2>/dev/null |
       grep -q "Name: $GITEA_ADMIN_USERNAME"; then
        log_success "Admin user '$GITEA_ADMIN_USERNAME' verified"
        return 0
    else
        log_error "Admin user '$GITEA_ADMIN_USERNAME' not found in database"
        return 1
    fi
}

wait_for_port_free() {
    log "Waiting for port $GITEA_PORT to be free..."

    local count=0
    while netstat -ln 2>/dev/null | grep -q ":$GITEA_PORT " && [[ $count -lt 10 ]]; do
        sleep 1
        ((count++))
    done

    log_success "Port $GITEA_PORT is free"
}

main() {
    log "Starting Gitea setup process..."

    validate_env
    wait_for_database
    setup_directories
    create_config

    if [[ -f "$ADMIN_CREATED_FLAG" ]]; then
        log "Admin user already created (flag file exists), skipping setup"
    else
        log "Starting Gitea temporarily for admin user setup..."

        su-exec "$GITEA_USER" "$GITEA_BIN" web --config "$GITEA_CONFIG" &
        GITEA_PID=$!

        if wait_for_gitea; then
            if manage_admin_user && verify_admin_user; then
                touch "$ADMIN_CREATED_FLAG"
                chown "$GITEA_USER:$GITEA_USER" "$ADMIN_CREATED_FLAG"
                log_success "Admin user setup completed"
            else
                log_error "Admin user setup failed"
                exit 1
            fi
        else
            log_error "Gitea failed to start for admin setup"
            exit 1
        fi

        log "Stopping temporary Gitea instance..."
        kill -TERM "$GITEA_PID" 2>/dev/null || true
        wait "$GITEA_PID" 2>/dev/null || true
        unset GITEA_PID

        wait_for_port_free
    fi

    log "=== STARTING GITEA IN PRODUCTION MODE ==="
    log "Gitea will be available at http://localhost:$GITEA_PORT"
    log "Admin user: $GITEA_ADMIN_USERNAME"

    exec su-exec "$GITEA_USER" "$GITEA_BIN" web --config "$GITEA_CONFIG"
}

main "$@"
