# signal-forensics

Signal Desktop key extraction and decryption utilities for digital-forensic workflows.

This repository provides cross-platform scripts to recover the locally stored Signal Desktop database encryption key from a user profile by extracting the credential from the OS keychain/credential store and decrypting the `encryptedKey` value in Signal’s `config.json`.

The resulting key permits access to the Signal Desktop message databases for examination.

---

## Scope

Supported environments:

- macOS (Keychain)
- Windows (Credential Manager)

---

## Repository Contents

- `decrypt-signal-w-keychain.py` — decrypts Signal `encryptedKey` from `config.json` using extracted password  
- `signal-key-extractor_Mac.sh` — macOS Keychain password extractor  
- `signal-key.bat` — Windows credential extractor  
- `signal-preserver.sh` — optional preservation/acquisition helper for Mac that also preserves the Signal files and their metadata

---

## Signal Desktop Key Architecture

Signal Desktop protects its SQLite database with a randomly generated key stored as:

- `config.json` → `encryptedKey`
- OS credential store → password
- PBKDF2-SHA1 → key-encryption key (KEK)
- AES-128-CBC → encrypted database key

Decryption process:

```
password (OS credential)
        ↓
PBKDF2(password, salt="saltysalt", iter=1003)
        ↓
AES-128-CBC decrypt(encryptedKey)
        ↓
Signal database key
```

---

## Requirements

- Python 3.8+
- pycryptodome

Install:

```bash
pip install pycryptodome
```

---

## Workflow

### 1. Extract Signal credential

#### macOS
```bash
chmod +x ./signal-key-extractor_Mac.sh
./signal-key-extractor_Mac.sh > signal_password.txt
```

#### Windows
```bat
signal-key.bat > signal_password.txt
```


---

### 2. Decrypt Signal database key

Default macOS path is used if the -c option is not specified.

```bash
python3 decrypt-signal-w-keychain.py  -c {Path to Signal config.json file} -p signal_password.txt
```

Output:

```
<Signal database key>
```

Save to file:

```bash
python3 decrypt-signal-w-keychain.py  -c {Path to Signal config.json file} -p signal_password.txt   -o signal_db_key.txt
```

---

## Signal Artifact Locations

| OS | Signal config |
|----|--------------|
macOS | `~/Library/Application Support/Signal/config.json` |
Windows | `%APPDATA%\Signal\config.json` |

Associated database typically resides in the Signal profile directory under the sql folder.


---


## Notes

- Requires access to unlocked user credential store
- Not applicable to mobile Signal databases
- Does not decrypt database automatically (key only)

---

## Legal & Ethical Use

This tool is intended solely for lawful digital forensic purposes.

Ensure:

- Legal authority to access the system
- Compliance with jurisdictional law
- Proper evidentiary handling procedures

Author assumes no liability for misuse.


---

## License

MIT
