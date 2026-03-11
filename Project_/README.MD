Smart backup system with error handling.

## Description

The Smart Backup System with Error Handling is a Bash-based automation program that is created to generate automatic backups of valuable directories within a Linux system. The script gives the user the option to schedule backups on frequent occasions and control numerous versions of backups.

This is done by the system which monitors a pre-set source directory and copies the information to a backup location. Every backup is stored with a timelines of the time, which assists users to determine the time when a backup was done.

One of the important properties of this system is the error handling. Some of the problems that are checked by the script include:

* Missing source directories
* Failed file copy operations
* Two or more backups are executed simultaneously.
* Configuration file errors

In case a problem arises the script logs the problem in the log files and the user can then go and debug the problem. Another provision in the script is the automatic cleanup, which removes older backups after the limit has been reached.

The system is scheduled with the help of the cron that enables the backup process to be performed automatically without the need of the intervention of the user.



## How to Run the Script

### 1. Make the Script Executable

Prior to executing the script allow it to execute:

```bash
chmod +x smart_backup.sh
```

### 2. Install the Backup System

Install it by running the following:

```bash
./smart_backup.sh install
```

The user will be required to give:

* The location of the files to be backed up
* The destination directory into which the backups will be kept.
* The **backup interval**
* The **number of backups to keep**

After the installation has taken place, the backup service will be automatically activated.

### 3. Check Backup Status

In order to see the existing status of backup system:

```bash
./smart_backup.sh status
```

### 4. View Backup Logs

In order to verify recent activity of backup:

```bash
./smart_backup.sh logs
```

### 5. Watch Logs in Real Time

```bash
./smart_backup.sh watch
```

### 6. Run a Manual Backup

```bash
./smart_backup.sh run
```

### 7. Stop the Backup Service

```bash
./smart_backup.sh stop
```

### 8. Start the Backup Service

```bash
./smart_backup.sh start
```

## Backup Storage

The backups are stored in the destination directory under a timestamp format:

```
directoryname_YYYYMMDD_HHMMSS
```

Example:

```
project_backup
```

Such a format assists in following various backup copies.


## Error Handling Features

Various mechanisms that are used to avoid failures are included in the script:

* Test to determine the presence of the **source directory or not.
* Supports avoiding having many instances of backup running at the same time by using PID(Process Identifier) files.
* Error and activity recording in the log files for easy troubleshooting.
* Falls back to cp(Copy) in case rsync(Remote Sync) is not installed.
* Pauses partially made backups in case of copying failure.