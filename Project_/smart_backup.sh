#!/bin/bash

# HEADLESS SERVER AUTO-BACKUP SYSTEM
# Fixed version with proper stop functionality

# ============================================
# CONFIGURATION (User-space version)
# ============================================
CONFIG_DIR="$HOME/.smartbackup"
CONFIG_FILE="$CONFIG_DIR/server_backup.conf"
LOG_DIR="$CONFIG_DIR/logs"
BACKUP_SCRIPT="$HOME/.local/bin/smartbackup"
MANAGER_SCRIPT="$HOME/.local/bin/smartbackup-manager"
PID_FILE="$CONFIG_DIR/smartbackup.pid"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Create directories
setup_directories() {
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$LOG_DIR"
    mkdir -p "$(dirname "$BACKUP_SCRIPT")"
    mkdir -p "$HOME/backup"
}

# Function to stop the backup service
stop_backup_service() {
    echo -e "${YELLOW}Stopping backup service...${NC}"
    
    # Remove from crontab
    crontab -l | grep -v "$BACKUP_SCRIPT" | crontab -
    
    # Kill any running backup processes
    pkill -f "$BACKUP_SCRIPT" 2>/dev/null
    
    # Remove PID file if it exists
    rm -f "$PID_FILE" 2>/dev/null
    
    echo -e "${GREEN}✅ Backup service stopped successfully${NC}"
    echo "No automatic backups will run until you start the service again."
}

# Function to start the backup service
start_backup_service() {
    echo -e "${GREEN}Starting backup service...${NC}"
    
    # Add to crontab (runs every minute)
    (crontab -l 2>/dev/null | grep -v "$BACKUP_SCRIPT"; echo "* * * * * $BACKUP_SCRIPT") | crontab -
    
    echo -e "${GREEN}✅ Backup service started successfully${NC}"
    echo "The service will check every minute if it's time to backup."
}

# Function to check status
check_status() {
    echo "════════════════════════════════════════════"
    echo "  BACKUP SERVICE STATUS"
    echo "════════════════════════════════════════════"
    
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        
        echo "Source:      $SOURCE_DIR"
        echo "Destination: $DEST_DIR"
        echo "Last Backup: $LAST_BACKUP"
        echo "Total:       $TOTAL_BACKUPS backups"
        echo "Keeping:     Last $KEEP_COUNT backups"
        echo "Interval:    Every ${INTERVAL%m} minutes"
        
        # Check if service is running (in crontab)
        if crontab -l 2>/dev/null | grep -q "$BACKUP_SCRIPT"; then
            echo -e "Status:      ${GREEN}RUNNING${NC} (in crontab)"
        else
            echo -e "Status:      ${RED}STOPPED${NC}"
        fi
        
        echo
        echo "Recent Backups:"
        ls -ltd "$DEST_DIR/${BACKUP_NAME}_"* 2>/dev/null | head -5 | while read line; do
            backup_name=$(basename "$line")
            backup_time=$(echo "$backup_name" | grep -o '[0-9]\{8\}_[0-9]\{6\}')
            if [ -n "$backup_time" ]; then
                formatted_time=$(date -d "${backup_time:0:8} ${backup_time:9:2}:${backup_time:11:2}:${backup_time:13:2}" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)
                echo "  $formatted_time - $backup_name"
            else
                echo "  $backup_name"
            fi
        done
    else
        echo -e "${RED}No backup service installed. Run install first.${NC}"
    fi
}

# ============================================
# INSTALLATION FUNCTION
# ============================================
install_backup_service() {
    echo "════════════════════════════════════════════"
    echo "  HEADLESS SERVER BACKUP INSTALLATION"
    echo "════════════════════════════════════════════"
    echo "This will install a 24/7 automatic backup system"
    echo
    
    # Get source directory
    read -p "Enter directory to backup: " SOURCE_DIR
    SOURCE_DIR="${SOURCE_DIR%/}"
    
    # Expand ~ if used
    SOURCE_DIR="${SOURCE_DIR/#\~/$HOME}"
    
    if [ ! -d "$SOURCE_DIR" ]; then
        echo -e "${RED}❌ Error: Directory does not exist: $SOURCE_DIR${NC}"
        exit 1
    fi
    
    # Get backup destination
    read -p "Enter backup storage location [~/backup]: " DEST_DIR
    DEST_DIR="${DEST_DIR:-$HOME/backup}"
    DEST_DIR="${DEST_DIR%/}"
    DEST_DIR="${DEST_DIR/#\~/$HOME}"
    
    mkdir -p "$DEST_DIR"
    
    # Backup frequency with MINUTE option for testing
    echo
    echo "Select backup frequency:"
    echo "1) Every minute (TESTING ONLY)"
    echo "2) Every hour"
    echo "3) Every 6 hours"
    echo "4) Every 12 hours"
    echo "5) Daily at midnight"
    echo "6) Custom interval (in minutes)"
    read -p "Choice [1-6]: " FREQ
    
    case $FREQ in
        1) INTERVAL="1m" ;;
        2) INTERVAL="60m" ;;
        3) INTERVAL="360m" ;;
        4) INTERVAL="720m" ;;
        5) INTERVAL="1440m" ;;
        6) 
            read -p "Enter interval in minutes (e.g., 5 for every 5 minutes): " MINUTES
            INTERVAL="${MINUTES}m"
            ;;
        *) INTERVAL="60m" ;;
    esac
    
    INTERVAL_NUM=${INTERVAL%m}
    
    read -p "How many backups to keep? (default: 10): " KEEP_COUNT
    KEEP_COUNT=${KEEP_COUNT:-10}
    
    BACKUP_NAME=$(basename "$SOURCE_DIR" | sed 's/[^a-zA-Z0-9]/_/g')
    
    # Save configuration
    cat > "$CONFIG_FILE" << EOF
# SmartBackup User Configuration
# Created: $(date)

SOURCE_DIR="$SOURCE_DIR"
DEST_DIR="$DEST_DIR"
BACKUP_NAME="$BACKUP_NAME"
KEEP_COUNT="$KEEP_COUNT"
INTERVAL="$INTERVAL"
LAST_BACKUP="never"
TOTAL_BACKUPS="0"
EOF
    
    chmod 600 "$CONFIG_FILE"
    
    # Create the backup script
    cat > "$BACKUP_SCRIPT" << 'EOF'
#!/bin/bash

# ============================================
# SMARTBACKUP - User-space Backup Daemon
# ============================================

CONFIG_DIR="$HOME/.smartbackup"
CONFIG_FILE="$CONFIG_DIR/server_backup.conf"
LOG_DIR="$CONFIG_DIR/logs"
PID_FILE="$CONFIG_DIR/smartbackup.pid"

# Colors (if running interactively)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
fi

# Source configuration
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "ERROR: Configuration not found at $CONFIG_FILE"
    exit 1
fi

# Function to log messages
log() {
    local level="$1"
    local message="$2"
    local log_file="$LOG_DIR/backup_$(date +%Y%m%d).log"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    echo "[$timestamp] [$level] $message" >> "$log_file"
    
    if [ -t 1 ]; then
        case "$level" in
            "ERROR")   echo -e "${RED}[$level]${NC} $message" ;;
            "WARNING") echo -e "${YELLOW}[$level]${NC} $message" ;;
            "SUCCESS") echo -e "${GREEN}[$level]${NC} $message" ;;
            "INFO")    echo -e "${BLUE}[$level]${NC} $message" ;;
        esac
    fi
}

# Function to check if backup is needed
should_run_backup() {
    local last_run_file="$LOG_DIR/last_run"
    
    if [ ! -f "$last_run_file" ]; then
        return 0
    fi
    
    local last_run=$(cat "$last_run_file")
    local current_time=$(date +%s)
    
    local interval_value=${INTERVAL%m}
    local interval_seconds=$((interval_value * 60))
    
    if [ $((current_time - last_run)) -ge $interval_seconds ]; then
        return 0
    else
        return 1
    fi
}

# Function to perform backup
do_backup() {
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_path="$DEST_DIR/${BACKUP_NAME}_${timestamp}"
    
    log "INFO" "Starting automatic backup of $SOURCE_DIR"
    
    if [ ! -d "$SOURCE_DIR" ]; then
        log "ERROR" "Source directory $SOURCE_DIR not found!"
        return 1
    fi
    
    if mkdir -p "$backup_path"; then
        log "INFO" "Created backup directory: $backup_path"
    else
        log "ERROR" "Failed to create backup directory"
        return 1
    fi
    
    log "INFO" "Copying files..."
    
    if command -v rsync &>/dev/null; then
        if rsync -a --delete "$SOURCE_DIR/" "$backup_path/" > "$LOG_DIR/rsync.log" 2>&1; then
            log "SUCCESS" "rsync backup completed"
        else
            log "WARNING" "rsync had issues, falling back to cp"
            cp -r "$SOURCE_DIR"/* "$backup_path/" 2>/dev/null || cp -r "$SOURCE_DIR"/. "$backup_path/" 2>/dev/null
        fi
    else
        if cp -r "$SOURCE_DIR"/* "$backup_path/" 2>/dev/null || cp -r "$SOURCE_DIR"/. "$backup_path/" 2>/dev/null; then
            log "SUCCESS" "cp backup completed"
        else
            log "ERROR" "Backup failed - copy error"
            rm -rf "$backup_path"
            return 1
        fi
    fi
    
    local file_count=$(find "$backup_path" -type f 2>/dev/null | wc -l)
    
    cat > "$backup_path/backup_info.txt" << METADATA
BACKUP INFORMATION
==================
Backup Time: $(date)
Source: $SOURCE_DIR
Files Backed Up: $file_count
Backup Type: Automatic
Backup ID: $timestamp
Host: $(hostname)
User: $(whoami)
METADATA
    
    ln -snf "$backup_path" "$DEST_DIR/${BACKUP_NAME}_latest"
    
    log "SUCCESS" "Backup completed: $file_count files at $backup_path"
    
    date +%s > "$LOG_DIR/last_run"
    
    # Update config
    sed -i.bak "s|LAST_BACKUP=.*|LAST_BACKUP=\"$(date)\"|" "$CONFIG_FILE"
    
    local total=$(grep TOTAL_BACKUPS "$CONFIG_FILE" | cut -d= -f2)
    total=$((total + 1))
    sed -i.bak "s/TOTAL_BACKUPS=.*/TOTAL_BACKUPS=$total/" "$CONFIG_FILE"
    
    clean_old_backups
    
    return 0
}

# Function to clean old backups
clean_old_backups() {
    log "INFO" "Checking for old backups..."
    
    local backups=($(ls -d "$DEST_DIR/${BACKUP_NAME}_"* 2>/dev/null | sort -r))
    local count=${#backups[@]}
    
    if [ $count -gt $KEEP_COUNT ]; then
        local to_delete=$((count - KEEP_COUNT))
        log "INFO" "Removing $to_delete old backup(s) (keeping last $KEEP_COUNT)"
        
        for ((i=$KEEP_COUNT; i<$count; i++)); do
            rm -rf "${backups[$i]}"
            log "INFO" "Removed: $(basename "${backups[$i]}")"
        done
    fi
}

# Main execution
log "INFO" "Backup service checking..."

if [ -f "$PID_FILE" ]; then
    old_pid=$(cat "$PID_FILE")
    if kill -0 "$old_pid" 2>/dev/null; then
        log "INFO" "Another instance running (PID: $old_pid), exiting"
        exit 0
    fi
fi

echo $$ > "$PID_FILE"

if should_run_backup; then
    interval_minutes=${INTERVAL%m}
    log "INFO" "Time to run backup (interval: ${interval_minutes} minutes)"
    do_backup
else
    log "DEBUG" "Not time to run yet"
fi

rm -f "$PID_FILE"

exit 0
EOF

    chmod 755 "$BACKUP_SCRIPT"
    
    # Start the service
    start_backup_service
    
    echo
    echo "════════════════════════════════════════════"
    echo -e "${GREEN}✅ BACKUP SERVICE INSTALLED SUCCESSFULLY!${NC}"
    echo "════════════════════════════════════════════"
    echo "Source:      $SOURCE_DIR"
    echo "Destination: $DEST_DIR"
    echo "Frequency:   Every $INTERVAL_NUM minute(s)"
    echo "Keep:        Last $KEEP_COUNT backups"
    echo
    echo -e "${YELLOW}The service is NOW RUNNING!${NC}"
    echo
    echo "Commands to manage:"
    echo "  ./smart_backup.sh status  # Check status"
    echo "  ./smart_backup.sh logs    # View logs"
    echo "  ./smart_backup.sh watch   # Watch logs live"
    echo "  ./smart_backup.sh run     # Run backup now"
    echo "  ./smart_backup.sh stop    # STOP the service"
    echo "  ./smart_backup.sh start   # START the service"
    echo
    echo "Logs are in: $LOG_DIR"
    echo "Config in:   $CONFIG_FILE"
    echo
}

# Function to view logs
view_logs() {
    if [ -d "$LOG_DIR" ]; then
        echo "════════════════════════════════════════════"
        echo "  RECENT LOGS"
        echo "════════════════════════════════════════════"
        tail -30 "$LOG_DIR"/backup_*.log 2>/dev/null || echo "No logs found"
    else
        echo "No logs found"
    fi
}

# Function to watch logs
watch_logs() {
    if [ -d "$LOG_DIR" ]; then
        echo "Watching logs (Ctrl+C to stop)..."
        tail -f "$LOG_DIR"/backup_*.log 2>/dev/null || echo "No logs found"
    else
        echo "No logs found"
    fi
}

# Function to run manual backup
run_manual() {
    echo "Running manual backup..."
    if [ -f "$BACKUP_SCRIPT" ]; then
        "$BACKUP_SCRIPT"
    else
        echo -e "${RED}Backup script not found. Run install first.${NC}"
    fi
}

# ============================================
# MAIN
# ============================================

setup_directories

case "${1:-}" in
    "install")
        install_backup_service
        ;;
    "stop")
        stop_backup_service
        ;;
    "start")
        start_backup_service
        ;;
    "status")
        check_status
        ;;
    "logs")
        view_logs
        ;;
    "watch")
        watch_logs
        ;;
    "run")
        run_manual
        ;;
    *)
        cat << EOF
SmartBackup - 24/7 Automatic Backup System

USAGE:
  ./smart_backup.sh install   - Install backup service (first time only)
  ./smart_backup.sh status    - Check backup status
  ./smart_backup.sh logs      - View backup logs
  ./smart_backup.sh watch     - Watch logs in real-time
  ./smart_backup.sh run       - Run backup manually
  ./smart_backup.sh stop      - STOP the service
  ./smart_backup.sh start     - START the service

FEATURES:
  • Minute-based intervals for testing (try every 1 minute!)
  • Runs in user space (no sudo needed)
  • Automatic cleanup of old backups
  • Timestamp-based versioning
  • 24/7 operation via cron
EOF
        ;;
esac