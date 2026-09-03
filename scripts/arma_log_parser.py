#!/usr/bin/env python3
"""
Arma 3 Docker Log Parser & Player Login Tracker
script for VPS execution via cron.

*example use:
#!/bin/bash
PYTHON_EXEC="/usr/bin/python3"
SCRIPT_PATH="/arma_log_parser.py"
OUTPUT_CSV="/players_last_login.csv"
STATE_FILE="/.arma_parser_state.json"
CONTAINER="a3..."
$PYTHON_EXEC $SCRIPT_PATH -c $CONTAINER -o $OUTPUT_CSV -s $STATE_FILE

*example cron:
0 5 * * * /home/username/arma_stats/run_arma_log_parser.sh >> /home/username/arma_stats/cron_parser.log 2>&1
"""

import os
import sys
import re
import json
import argparse
import subprocess
from datetime import datetime
from typing import Dict, Any, Optional, Tuple, Generator, Set

# --- TYPES & SCHEMAS ---
# Schema for Player Record: { SteamID: { "name": Name, "last_login": ISO_Timestamp } }
PlayerDict = Dict[str, Dict[str, str]]


def log_info(msg: str) -> None:
    """Print standard informational log message."""
    print(f"[INFO] {datetime.now().isoformat()} - {msg}", file=sys.stderr)


def log_error(msg: str) -> None:
    """Print standard error log message."""
    print(f"[ERROR] {datetime.now().isoformat()} - {msg}", file=sys.stderr)


def parse_iso_timestamp(ts_str: str) -> datetime:
    """
    Safely parse ISO 8601 timestamp with micro/nanoseconds and timezone.
    Handles 'Z' suffix and potential sub-second precision differences.
    """
    # Normalize 'Z' to UTC offset
    normalized = ts_str.strip()
    if normalized.endswith("Z"):
        normalized = normalized[:-1] + "+00:00"
    
    # Docker sometimes provides nanosecond precision (9 digits after dot), 
    # but Python's fromisoformat only supports up to microsecond precision (6 digits).
    # We must slice the fractional seconds to maximum of 6 digits if present.
    if "." in normalized:
        base, frac_tz = normalized.split(".", 1)
        # Find timezone start (either + or - or offset)
        tz_index = -1
        for sign in ("+", "-"):
            tz_index = frac_tz.find(sign)
            if tz_index != -1:
                break
        
        if tz_index != -1:
            frac = frac_tz[:tz_index]
            tz = frac_tz[tz_index:]
        else:
            frac = frac_tz
            tz = ""
            
        # Truncate fractional digits to microsecond level (6 digits)
        frac = frac[:6]
        normalized = f"{base}.{frac}{tz}"

    try:
        return datetime.fromisoformat(normalized)
    except ValueError as e:
        raise ValueError(f"Failed to parse timestamp '{ts_str}' (normalized: '{normalized}'): {e}")


def check_system_sanity(container_name: str, output_path: str, is_file_mode: bool) -> None:
    """
    Perform structural and system checks: permissions, directories, container status.
    """
    log_info("Running system sanity checks...")
    
    # 1. Output directory write permission check
    out_dir = os.path.dirname(os.path.abspath(output_path))
    if not os.path.exists(out_dir):
        log_info(f"Output directory '{out_dir}' does not exist. Creating it.")
        try:
            os.makedirs(out_dir, exist_ok=True)
        except Exception as e:
            log_error(f"Cannot create output directory '{out_dir}': {e}")
            sys.exit(1)
            
    if not os.access(out_dir, os.W_OK):
        log_error(f"Output directory '{out_dir}' is not writable.")
        sys.exit(1)
        
    if os.path.exists(output_path) and not os.access(output_path, os.W_OK):
        log_error(f"Output file '{output_path}' exists but is not writable.")
        sys.exit(1)

    if is_file_mode:
        log_info("Running in local file mode; skipping Docker container checks.")
        return

    # 2. Check if docker is installed
    try:
        subprocess.run(["docker", "--version"], capture_output=True, check=True)
    except (subprocess.CalledProcessError, FileNotFoundError):
        log_error("Docker executable not found or not in PATH. Are we on the VPS?")
        sys.exit(1)

    # 3. Check if container exists and is running
    try:
        res = subprocess.run(
            ["docker", "inspect", "-f", "{{.State.Running}}", container_name],
            capture_output=True,
            text=True,
            check=False
        )
        if res.returncode != 0:
            err_msg = res.stderr.strip() if res.stderr else "No stderr output"
            log_info(f"Skipping container check due to inspect failure (exit code {res.returncode}): {err_msg}")
        elif res.stdout.strip() != "true":
            log_info(f"Container '{container_name}' is not currently running, but we will proceed parsing static/cached logs.")
    except Exception as e:
        log_error(f"Unexpected error inspecting Docker container: {e}")
        sys.exit(1)


def load_existing_players(file_path: str) -> PlayerDict:
    """
    Load previous player login tracking data from the output file (CSV format).
    Expected columns: SteamID,Name,LastLogin
    """
    players: PlayerDict = {}
    if not os.path.exists(file_path):
        log_info(f"No existing output file found at '{file_path}'. A new one will be created.")
        return players

    log_info(f"Loading existing player records from '{file_path}'...")
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            lines = f.readlines()
            for line_no, line in enumerate(lines, 1):
                line = line.strip()
                if not line or line.startswith("SteamID,"):
                    continue # Skip empty or headers
                parts = line.split(",", 2)
                if len(parts) == 3:
                    steam_id, name, last_login = parts
                    players[steam_id] = {"name": name, "last_login": last_login}
                else:
                    log_error(f"Malformed line {line_no} in output file: '{line}'. Skipping.")
    except Exception as e:
        log_error(f"Could not read existing file '{file_path}': {e}. Starting fresh.")
        
    return players


def save_players_atomic(file_path: str, players: PlayerDict) -> None:
    """
    Atomically write the player login tracking data to prevent data corruption/mangling.
    """
    log_info(f"Saving merged player records atomically to '{file_path}'...")
    tmp_path = f"{file_path}.tmp"
    try:
        with open(tmp_path, "w", encoding="utf-8") as f:
            f.write("SteamID,Name,LastLogin\n")
            # Sort by Name or LastLogin for structured presentation
            sorted_players = sorted(players.items(), key=lambda x: x[1]["name"].lower())
            for steam_id, info in sorted_players:
                # Escape commas in names to prevent malformed CSV rows
                escaped_name = info["name"].replace(",", " ")
                f.write(f"{steam_id},{escaped_name},{info['last_login']}\n")
        
        # Atomic rename (POSIX guarantees replacement is atomic)
        os.replace(tmp_path, file_path)
        log_info(f"Successfully wrote {len(players)} player records.")
    except Exception as e:
        log_error(f"Failed to write output file atomically: {e}")
        if os.path.exists(tmp_path):
            try:
                os.remove(tmp_path)
            except OSError:
                pass
        sys.exit(1)


def save_players_pretty(file_path: str, players: PlayerDict) -> None:
    """
    Write a second file with suffix _pretty containing:
    YYMMDD Name
    Sorted descending by the most recent login time (most active first).
    """
    base, _ = os.path.splitext(file_path)
    pretty_path = f"{base}_pretty.txt"
    log_info(f"Saving pretty player records to '{pretty_path}'...")
    
    try:
        # Sort descending by chronological datetime value
        sorted_players = sorted(
            players.items(),
            key=lambda x: parse_iso_timestamp(x[1]["last_login"]),
            reverse=True
        )
    except Exception as e:
        log_error(f"Failed to sort players chronologically for pretty output: {e}. Falling back to name sort.")
        sorted_players = sorted(players.items(), key=lambda x: x[1]["name"].lower())

    tmp_path = f"{pretty_path}.tmp"
    try:
        with open(tmp_path, "w", encoding="utf-8") as f:
            for steam_id, info in sorted_players:
                try:
                    dt = parse_iso_timestamp(info["last_login"])
                    yymmdd = dt.strftime("%y%m%d")
                except ValueError:
                    yymmdd = "000000"
                f.write(f"{yymmdd} {info['name']}\n")
        
        os.replace(tmp_path, pretty_path)
        log_info(f"Successfully wrote pretty formatting for {len(players)} players.")
    except Exception as e:
        log_error(f"Failed to write pretty output file atomically: {e}")
        if os.path.exists(tmp_path):
            try:
                os.remove(tmp_path)
            except OSError:
                pass


def load_state(state_path: str) -> Optional[str]:
    """Load the last parsed ISO timestamp from the state cache."""
    if os.path.exists(state_path):
        try:
            with open(state_path, "r", encoding="utf-8") as f:
                data = json.load(f)
                return data.get("last_timestamp")
        except Exception as e:
            log_error(f"Could not load state file '{state_path}': {e}")
    return None


def save_state(state_path: str, timestamp: str) -> None:
    """Save the last parsed ISO timestamp to the state cache."""
    try:
        with open(state_path, "w", encoding="utf-8") as f:
            json.dump({"last_timestamp": timestamp}, f, indent=2)
    except Exception as e:
        log_error(f"Could not save state to '{state_path}': {e}")


def stream_docker_logs(container_name: str, since_ts: Optional[str], time_slice: Optional[str]) -> Generator[str, None, None]:
    """
    Stream logs from Docker using standard subprocess, ensuring low memory foot-print.
    """
    cmd = ["docker", "logs", "-t"]
    
    # Decide since argument
    if time_slice:
        cmd += ["--since", time_slice]
        log_info(f"Fetching logs since configured time slice: {time_slice}")
    elif since_ts:
        cmd += ["--since", since_ts]
        log_info(f"Fetching logs since last cached timestamp: {since_ts}")
    else:
        # Default fallback to 24h to avoid scanning enormous history if no state exists
        cmd += ["--since", "24h"]
        log_info("No state or slice found. Defaulting to fetching logs from last 24 hours.")

    cmd.append(container_name)
    
    log_info(f"Executing: {' '.join(cmd)}")
    
    try:
        # Docker outputs logs to both stdout and stderr. 
        # We capture both merged to make sure we parse properly.
        process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding="utf-8")
    except Exception as e:
        log_error(f"Failed to spawn Docker logs process: {e}")
        return

    # Yield line by line to maintain constant O(1) memory complexity, while keeping a small ring buffer
    # to capture and report standard error/output in case of process failure.
    captured_lines = []
    if process.stdout:
        for line in process.stdout:
            captured_lines.append(line.rstrip("\r\n"))
            if len(captured_lines) > 20:
                captured_lines.pop(0)
            yield line

    process.wait()
    if process.returncode != 0:
        log_error(f"Docker logs command failed with exit code {process.returncode}")
        if captured_lines:
            log_error("Last captured output lines from the failed command:")
            for err_line in captured_lines:
                log_error(f"  > {err_line}")


def stream_file_logs(file_path: str) -> Generator[str, None, None]:
    """Stream logs from a local file for offline validation."""
    log_info(f"Streaming logs from offline file: '{file_path}'")
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            for line in f:
                yield line
    except Exception as e:
        log_error(f"Failed to read file '{file_path}': {e}")


def parse_log_stream(line_generator: Generator[str, None, None]) -> Tuple[PlayerDict, Optional[str]]:
    """
    Core parsing algorithm. Walks lines, extracts connection events, updates timestamps.
    Returns the mapped player dict and the latest seen timestamp.
    """
    new_players: PlayerDict = {}
    latest_timestamp: Optional[str] = None
    
    # Matches ISO Timestamp (Group 1), Player Name (Group 2), and SteamID (Group 3)
    # Handles potential wild spaces or variable names safely.
    pattern = re.compile(r"^([0-9\-T:\.Z]+)\s+.*?Player\s+(.+?)\s+connected\s+\(id=([0-9]+)\)")
    
    parsed_count = 0
    total_count = 0

    for line in line_generator:
        total_count += 1
        match = pattern.match(line)
        if match:
            parsed_count += 1
            ts_str, name, steam_id = match.groups()
            
            # Defensive check: validate ID and Name length
            if not steam_id or not name:
                continue
            
            try:
                # Validate the timestamp format
                parse_iso_timestamp(ts_str)
            except ValueError as e:
                log_error(f"Skipping line with invalid timestamp structure: {e}")
                continue

            # Update latest parsed timestamp strictly chronologically
            if latest_timestamp is None:
                latest_timestamp = ts_str
            else:
                try:
                    if parse_iso_timestamp(ts_str) > parse_iso_timestamp(latest_timestamp):
                        latest_timestamp = ts_str
                except ValueError:
                    pass

            # Store the absolute latest connection details for this player
            # If they connect multiple times in this stream, the latest one wins
            if steam_id in new_players:
                try:
                    curr_ts = parse_iso_timestamp(ts_str)
                    prev_ts = parse_iso_timestamp(new_players[steam_id]["last_login"])
                    if curr_ts > prev_ts:
                        new_players[steam_id] = {"name": name, "last_login": ts_str}
                except ValueError:
                    # Fallback overwrite if datetime comparisons fail
                    new_players[steam_id] = {"name": name, "last_login": ts_str}
            else:
                new_players[steam_id] = {"name": name, "last_login": ts_str}

    log_info(f"Parsed {parsed_count} connections from {total_count} processed lines.")
    return new_players, latest_timestamp


def merge_and_update(existing: PlayerDict, fresh: PlayerDict) -> PlayerDict:
    """
    Merges existing tracking records with freshly parsed connections.
    Always maintains the absolute latest timestamp per SteamID.
    """
    merged = dict(existing)
    for steam_id, fresh_info in fresh.items():
        if steam_id in merged:
            try:
                fresh_ts = parse_iso_timestamp(fresh_info["last_login"])
                merged_ts = parse_iso_timestamp(merged[steam_id]["last_login"])
                if fresh_ts > merged_ts:
                    merged[steam_id] = fresh_info
            except ValueError:
                # Fallback to fresh if parser comparison fails
                merged[steam_id] = fresh_info
        else:
            merged[steam_id] = fresh_info
    return merged


def create_arg_parser() -> argparse.ArgumentParser:
    """Generate unix-compliant manual/help documentation."""
    parser = argparse.ArgumentParser(
        description="Arma 3 Docker Log Parser: Tracks player last-login metrics chronologically from Docker JSON-file or local streams.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Usage Examples:
  1. Cron Mode (Default VPS execution, utilizing cached states):
     python3 arma_log_parser.py -c containername -o /var/www/stats/players.txt -s .state.json

  2. Manual Back-fill Slice:
     python3 arma_log_parser.py -c containername -o players.txt --time-slice 48h

  3. Offline Parsing of static dump (Testing/Debugging):
     python3 arma_log_parser.py -f docker_logs-100k.txt -o players.txt --offline
"""
    )
    
    parser.add_argument(
        "-c", "--container",
        default="containername",
        help="The target Arma 3 Docker container name. (default: containername)"
    )
    
    parser.add_argument(
        "-o", "--output",
        required=True,
        help="Output file path where player login data is saved (CSV format)."
    )
    
    parser.add_argument(
        "-s", "--state",
        default=".arma_parser_state.json",
        help="Path to JSON state file used for caching the last parsed timestamp. (default: .arma_parser_state.json)"
    )
    
    parser.add_argument(
        "-t", "--time-slice",
        help="Override state cache and fetch logs since specified time slice (e.g. '24h', '7d', '1h'). Passes directly to Docker."
    )
    
    parser.add_argument(
        "-f", "--file",
        help="Read logs from a local file instead of query Docker container. Forces offline mode."
    )
    
    parser.add_argument(
        "--offline",
        action="store_true",
        help="Disables all Docker container validation and queries."
    )

    return parser


def main() -> None:
    parser = create_arg_parser()
    args = parser.parse_args()

    is_offline = bool(args.file or args.offline)
    
    # 1. Sanity Checks
    check_system_sanity(args.container, args.output, is_offline)

    # 2. Load cached logs timestamp if not overridden by dynamic slice
    since_ts: Optional[str] = None
    if not args.time_slice and not is_offline:
        since_ts = load_state(args.state)
        if since_ts:
            log_info(f"Resuming parsing from cached timestamp: {since_ts}")
        else:
            log_info("No existing state file found. Will perform fallback query.")

    # 3. Stream Selection
    if args.file:
        line_generator = stream_file_logs(args.file)
    else:
        line_generator = stream_docker_logs(args.container, since_ts, args.time_slice)

    # 4. Parsing
    fresh_players, latest_seen_ts = parse_log_stream(line_generator)

    # 5. Merging existing data
    existing_players = load_existing_players(args.output)
    merged_players = merge_and_update(existing_players, fresh_players)

    # 6. Atomic save of CSV data
    save_players_atomic(args.output, merged_players)
    save_players_pretty(args.output, merged_players)

    # 7. Update state file if we parsed a valid chronological timestamp
    if latest_seen_ts and not is_offline and not args.time_slice:
        log_info(f"Updating parser cache timestamp to: {latest_seen_ts}")
        save_state(args.state, latest_seen_ts)

    log_info("Arma 3 log parser execution finished successfully.")


if __name__ == "__main__":
    main()


