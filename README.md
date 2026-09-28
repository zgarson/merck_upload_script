# Merck Weekly PLD Upload

Automates the weekly Merck PLD (Physician Level Data) delivery. The script stages `.txt` response files into a date-stamped upload folder, appends a record-count row for each response file to the running RELEVATE audit file, includes a copy of that audit file with the delivery, and uploads the whole folder to Merck's S3 inbound bucket.

There are no paths to edit. The first time you run it, the script prompts for the two machine-specific paths it needs and saves them — every run after that is prompt-free.

It also supports a **test mode** that performs every step *except* the upload, so a new user can safely confirm the staging and audit output before anything leaves the machine.

---

## Contents

| File | Purpose |
|---|---|
| `merck_upload.sh` | **The script you run.** Handles setup, staging, the record count, and the S3 upload. |
| `record_count_v3.sh` | Support script — called automatically by `merck_upload.sh`. You do not run this directly. |

`merck_upload.sh` locates `record_count_v3.sh` relative to its own location, so the repo can be cloned anywhere and invoked from any working directory. Just keep the two files together.

---

## What it does

1. **Loads your saved config** — or runs first-time setup if this is your first execution (see [Setup](#setup)).

2. **Runs pre-flight checks** — confirms the source directory exists, the support script is present and executable, and the audit file's directory is reachable. It exits with a clear message rather than failing partway through.

3. **Creates a dated upload folder** under your staging directory, named `YYYYMMDD`. If that folder already exists (i.e. you're uploading more than once in a day), it creates `YYYYMMDD_2`, `YYYYMMDD_3`, and so on, so a previous delivery is never overwritten.

4. **Copies every `.txt` file** found recursively under the source directory (i.e. the Merck folder in Feeds_Deployed) into that upload folder.

5. **Appends audit rows** for each file whose name contains `Response`, in the format:

YEAR|YYYYMMDD|FILENAME|RECORD_COUNT
The record count is the line count minus one, to exclude the header row.

6. **Copies the updated audit file** into the upload folder so it ships with the delivery.

7. **Uploads the folder to S3** — unless test mode is on.

### Audit file handling

The audit file is a cumulative, append-only log, so the support script is careful with it:

- If the file doesn't end in a newline, one is added first — otherwise the first new row would be concatenated onto the last existing row.

- Each row is checked against the file before being written, so re-running the script won't create duplicate entries.

- The trailing newline is stripped at the end, leaving no blank line at the bottom of the file.

---

## Requirements

- macOS or Linux with `bash` (the setup prompts use bash readline, so invoke the script directly or with `bash` — not `sh`)

- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

- An AWS profile named `mercks3access` configured with write access to the Merck inbound bucket

- The CloudMounter share holding the audit file must be mounted before running

---

## Setup

> **Do not edit the scripts.** Everything machine-specific is collected on your first run and saved for you.

### Step 1 — Make the scripts executable

```bash
chmod +x merck_upload.sh record_count_v3.sh
Step 2 — Run the scriptSetup is triggered automatically by your first real run. Start with a dry run:./merck_upload.sh "/path/to/your/PLD/files" test
Step 3 — Answer the two promptsUpload staging directoryWhere dated delivery folders get created.Upload staging directory (where dated folders are created): ~/Data_Engineering/Merck Weekly PLDs
If the directory doesn't exist yet, you'll be offered the chance to create it:  '/Users/you/Data_Engineering/Merck Weekly PLDs' does not exist. Create it? [y/N]
Audit file pathThe full path to the RELEVATE audit .txt on the CloudMounter share.Full path to the RELEVATE audit file (.txt): /Users/you/Library/CloudStorage/CloudMounter-rh-data-processing/DataFeeds/audit_files/Merck/RELEVATE_Audit_2026.txt
If the share isn't mounted, you'll get a warning and can still save the path:  WARNING: '<parent directory>' is not currently reachable.
  If this lives on the CloudMounter share, mount it before running the upload.
  Save this path anyway? [y/N]
Both prompts accept ~, support tab-completion, and strip trailing slashes automatically.Step 4 — You're doneThe script confirms what it saved and continues straight into the upload:Saved:
  UPLOAD_DIR = /Users/you/Data_Engineering/Merck Weekly PLDs
  AUDIT_FILE = /Users/you/Library/.../RELEVATE_Audit_2026.txt
No further setup is needed. Future runs read these values silently.Where your settings are stored~/.config/merck_upload/config
This file lives outside the repo, so git pull never overwrites it and nobody's personal paths end up in a commit. It's created with 600 permissions and looks like this:# Merck Upload configuration
# Written 2026-09-28 13:04:22
# Re-run the script with --reconfigure to change these values.
UPLOAD_DIR="/Users/you/Data_Engineering/Merck Weekly PLDs"
AUDIT_FILE="/Users/you/Library/.../RELEVATE_Audit_2026.txt"
Reconfiguring your saved pathsUse this when your staging directory moves, or at the start of a new year when the audit file changes:./merck_upload.sh --reconfigure
This re-runs both prompts, overwrites the saved values, and exits without uploading anything:----------------------------------------------------------
 Merck Upload — reconfigure saved paths
----------------------------------------------------------
...
Configuration updated. Re-run the script with your source directory.
You can edit ~/.config/merck_upload/config by hand instead if you prefer — the script just sources it.Deleting the config fileRemoving the config resets the script to a clean, never-run state:rm ~/.config/merck_upload/config
The next time you run merck_upload.sh, first-time setup starts over from scratch. Nothing else is affected — your staging folders, previously uploaded deliveries, and the audit file are all left untouched.Use this if the config gets into a bad state, or to hand a colleague a clean starting point.Optional: add an aliasAdd this to ~/.zshrc (or ~/.bashrc if you use bash):alias merck_upload='/path/to/repo/merck_upload.sh'
Reload your shell:source ~/.zshrc
Usage./merck_upload.sh <source_directory> [test]
./merck_upload.sh --reconfigure
ArgumentRequiredDescriptionsource_directoryYesFolder containing the PLD .txt files. Searched recursively.testNoPass the literal string test to stage files and update the audit file without uploading to S3.--reconfigure—Used alone. Re-prompts for the saved paths and exits.Example usageFirst run./merck_upload.sh "/Users/zachgarson/Downloads/Merck_PLD_20260928" test
----------------------------------------------------------
 Merck Upload — first-time setup
----------------------------------------------------------
These paths are saved to /Users/zachgarson/.config/merck_upload/config
and reused automatically on every future run.

Upload staging directory (where dated folders are created): ~/Data_Engineering/Merck Weekly PLDs

Full path to the RELEVATE audit file (.txt): /Users/zachgarson/Library/CloudStorage/CloudMounter-rh-data-processing/DataFeeds/audit_files/Merck/RELEVATE_Audit_2026.txt

Saved:
  UPLOAD_DIR = /Users/zachgarson/Data_Engineering/Merck Weekly PLDs
  AUDIT_FILE = /Users/zachgarson/Library/CloudStorage/CloudMounter-rh-data-processing/DataFeeds/audit_files/Merck/RELEVATE_Audit_2026.txt
----------------------------------------------------------

Creating directory /Users/zachgarson/Data_Engineering/Merck Weekly PLDs/20260928
Test mode enabled. Files copied to /Users/zachgarson/Data_Engineering/Merck Weekly PLDs/20260928 but not uploaded.
Inspect the staged folder and the audit file, confirm the counts look right, then run it for real. Running a dry run first is recommended for new users.Real upload./merck_upload.sh "/Users/zachgarson/Downloads/Merck_PLD_20260928"
Creating directory /Users/zachgarson/Data_Engineering/Merck Weekly PLDs/20260928
upload: ...Merck Weekly PLDs/20260928/ACE_Response_001.txt to s3://com-merck-ghhusdw-prod-relevatehealth/inbound/ACE/ACE_Response_001.txt
upload: ...Merck Weekly PLDs/20260928/RELEVATE_Audit_2026.txt to s3://com-merck-ghhusdw-prod-relevatehealth/inbound/ACE/RELEVATE_Audit_2026.txt
Upload process completed. Files are in /Users/zachgarson/Data_Engineering/Merck Weekly PLDs/20260928.
Second upload on the same day./merck_upload.sh "/Users/zachgarson/Downloads/Merck_PLD_20260928_corrected"
Directory /Users/zachgarson/Data_Engineering/Merck Weekly PLDs/20260928 already exists. Creating a new directory with suffix _2.
...
Upload process completed. Files are in /Users/zachgarson/Data_Engineering/Merck Weekly PLDs/20260928_2.
With an alias configuredmerck_upload "/Users/zachgarson/Downloads/Merck_PLD_20260928" test
Sample audit file output
2026|20260921|ACE_Response_001.txt|14523
2026|20260921|ACE_Response_002.txt|8871
2026|20260928|ACE_Response_001.txt|15102
2026|20260928|ACE_Response_002.txt|9344
TroubleshootingMessage / symptomCause and fixERROR: source directory does not existTypo in the first argument, or the path needs quoting because it contains spaces.ERROR: support script not found or not executablerecord_count_v3.sh was moved out of the repo folder, or was never made executable — run chmod +x record_count_v3.sh.ERROR: audit file directory is not reachableThe CloudMounter share isn't mounted. Mount it and re-run. If the saved path itself is wrong, run --reconfigure.Usage message with no other outputNo source directory was passed.Setup prompts appear again unexpectedly~/.config/merck_upload/config was deleted, or one of its values is empty.No new lines in the audit fileNo filenames in the source directory contain Response, or the rows already exist (the duplicate guard skipped them).Unable to locate credentialsThe mercks3access profile isn't configured. Check aws configure list --profile mercks3access.Record counts are off by oneThe script assumes every response file has exactly one header row.Nothing uploaded, no errorSecond argument was test. Re-run without it.Notes

Only files whose name contains Response generate audit rows, but all .txt files found in the source directory are copied and uploaded.


record_count_v3.sh is safe to re-run — the duplicate check means it won't double up rows in the audit file.


The audit file is cumulative for the whole year. At the start of each year, run --reconfigure and point AUDIT_FILE at the new file.


The S3 destination bucket and the mercks3access profile name are hardcoded in merck_upload.sh, since they're the same for everyone on the team.

