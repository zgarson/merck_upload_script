# Merck Weekly PLD Upload

Automates the weekly Merck PLD (Physician Level Data) delivery. The script stages
`.txt` response files into a date-stamped upload folder, appends a record-count row
for each response file to the running RELEVATE audit file, includes a copy of that
audit file with the delivery, and uploads the whole folder to Merck's S3 inbound
bucket.

It also supports a **test mode** that performs every step *except* the upload, so a
new user can safely confirm the staging and audit output before anything leaves the
machine.

---

## Contents

| File | Purpose |
|---|---|
| `merck_upload.sh` | **The script you run.** Stages files, triggers the record count, and uploads to S3. |
| `record_count_v3.sh` | Support script — called automatically by `merck_upload.sh`. You do not run this directly. |

---

## What it does

1. **Creates a dated upload folder** under the configured upload directory, named
   `YYYYMMDD`. If that folder already exists (i.e. you're uploading more than once
   in a day), it creates `YYYYMMDD_2`, `YYYYMMDD_3`, and so on, so a previous
   delivery is never overwritten.
2. **Copies every `.txt` file** found recursively under the source directory (i.e. the Merck folder in Feeds_Deployed) into
   that upload folder.
3. **Appends audit rows** for each file whose name contains `Response`, in the
   format:
YEAR|YYYYMMDD|FILENAME|RECORD_COUNT The record count is the line count minus one, to exclude the header row.
4. **Copies the updated audit file** into the upload folder so it ships with the
delivery.
5. **Uploads the folder to S3** — unless test mode is on.

### Audit file handling

The audit file is a cumulative, append-only log, so the support script is careful
with it:

- Each row is checked against the file before being written, so re-running the
script won't create duplicate entries.
- The trailing newline is stripped at the end, leaving no blank line at the bottom
of the file.

---

## Requirements

- macOS or Linux with `bash`
- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- An AWS profile named `mercks3access` configured with write access to the Merck
inbound bucket
- The CloudMounter share holding the audit file must be mounted before running

---

## Setup

Clone the repo and make both scripts executable:

```bash
chmod +x merck_upload.sh record_count_v3.sh
Then open merck_upload.sh and set the three paths at the top to match your
machine:UPLOAD_DIR='/Users/<you>/Data_Engineering/Merck Weekly PLDs'
AUDIT_FILE="/Users/<you>/Library/CloudStorage/CloudMounter-rh-data-processing/DataFeeds/audit_files/Merck/RELEVATE_Audit_2026.txt"
Also update the hardcoded path to record_count_v3.sh further down the script so it
points at wherever you cloned the repo.Optional: add an aliasAdd this to ~/.zshrc (or ~/.bashrc if you use bash):alias merck_upload='/path/to/repo/merck_upload.sh'
Reload your shell:source ~/.zshrc
Usage./merck_upload.sh <source_directory> [test]
ArgumentRequiredDescriptionsource_directoryYesFolder containing the PLD .txt files. Searched recursively.testNoPass the literal string test to stage files and update the audit file without uploading to S3.Example usageDry run first (recommended for new users)./merck_upload.sh "/Users/zachgarson/Downloads/Merck_PLD_20260928" test
Output:Creating directory /Users/zachgarson/Data_Engineering/Merck Weekly PLDs/20260928
Test mode enabled. Files copied to /Users/zachgarson/Data_Engineering/Merck Weekly PLDs/20260928 but not uploaded.
Inspect the staged folder and the audit file, confirm the counts look right, then
run it for real.Real upload./merck_upload.sh "/Users/zachgarson/Downloads/Merck_PLD_20260928"
Output:Creating directory /Users/zachgarson/Data_Engineering/Merck Weekly PLDs/20260928
upload: ...Merck Weekly PLDs/20260928/ACE_Response_001.txt to s3://com-merck-ghhusdw-prod-relevatehealth/inbound/ACE/ACE_Response_001.txt
upload: ...Merck Weekly PLDs/20260928/RELEVATE_Audit_2026.txt to s3://com-merck-ghhusdw-prod-relevatehealth/inbound/ACE/RELEVATE_Audit_2026.txt
Upload process completed. Files are in /Users/zachgarson/Data_Engineering/Merck Weekly PLDs/20260928.
Second upload on the same day./merck_upload.sh "/Users/zachgarson/Downloads/Merck_PLD_20260928_corrected"
Output:Directory /Users/zachgarson/Data_Engineering/Merck Weekly PLDs/20260928 already exists. Creating a new directory with suffix _2.
...
Upload process completed. Files are in /Users/zachgarson/Data_Engineering/Merck Weekly PLDs/20260928_2.
With an alias configuredmerck_upload "/Users/zachgarson/Downloads/Merck_PLD_20260928" test
Sample audit file output
2026|20260921|ACE_Response_001.txt|14523
2026|20260921|ACE_Response_002.txt|8871
2026|20260928|ACE_Response_001.txt|15102
2026|20260928|ACE_Response_002.txt|9344
TroubleshootingSymptomLikely cause
No new lines in the audit file
No filenames in the source directory contain Response, or the rows already exist (duplicate guard skipped them).
No such file or directory on the audit path
The CloudMounter share isn't mounted. Mount it and re-run.Unable to locate credentialsThe mercks3access profile isn't configured. Check aws configure list --profile mercks3access.
Record counts are off by oneThe script assumes every response file has exactly one header row.Nothing uploaded, no errorSecond argument was test. Re-run without it.
Notes
Only files whose name contains Response generate audit rows, but all .txt
files found in the source directory are copied and uploaded.
record_count_v3.sh is safe to re-run — the duplicate check means it won't double
up rows in the audit file.
The audit file is cumulative for the whole year. Point AUDIT_FILE at a new file
at the start of each year.
