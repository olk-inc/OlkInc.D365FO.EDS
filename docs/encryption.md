[← Return to README](../README.md)

# Encrypted values for each environment

Secrets such as passwords, client secrets and tokens are kept in the master environment (normally PROD), like the rest of the setup. They are encrypted for the one environment they are meant for, so:

- the master cannot read them, in the form or in a database dump;
- they travel to the sandbox with the LCS database refresh, like the rest of the setup;
- only that sandbox can decrypt them, when its setup is [executed](execute.md) there.

Nothing has to be done after a refresh. Each sandbox is enrolled once.

## How it works

Every environment has its own RSA key pair (3072 bit).

1. The sandbox creates its key pair the first time it is asked for it. It locks the private key with its own platform encryption, the same encryption D365 uses for password fields, which depends on the environment's certificate. The certificate stays with the environment when its database is replaced.
2. The master gets the sandbox's public key and locked private key, either from the sandbox's **key service** (**Fetch key**) or from an **enrolment ZIP file** exported in the sandbox (**Import enrolment**). Both are stored on the sandbox's record in **Environments**. The master can use the public key but cannot unlock the private key.
3. When you enter the value of an [encrypted field](data-setup.md#encrypted-fields) for the sandbox, the master encrypts it immediately with the sandbox's public key and stores only the encrypted value.
4. The LCS refresh copies the master's database, with the sandbox's record and its encrypted values, to the sandbox.
5. **Execute environment data setup** in the sandbox unlocks the sandbox's private key, decrypts each value in memory and writes it through the target field's edit method. The value is never shown or logged.

In any other environment (the master, another sandbox, a development box restored from a backup) the private key cannot be unlocked, and the encrypted lines fail with an error.

An encrypted value is also bound to its line: environment, company, table, edit method and record. Copied to another line, it cannot be decrypted, so it cannot be redirected to a field that is visible.

```
 Sandbox UAT                                  Master PROD
 ───────────                                  ───────────
 key pair created, private key locked
 with UAT's certificate
            ── Fetch key (key service) ──▶    UAT record: URL, public key,
            ── or enrolment ZIP file   ──▶    locked private key, fingerprint
                                              values for UAT entered and
                                              encrypted with UAT's public key
            ◀──────── LCS refresh: PROD database copied to UAT ────────
 Execute environment data setup for UAT:
 unlock the private key, decrypt, write
```

## One-time setup

### 1. Install the model in every environment

The model must be deployed to the master and to every sandbox that is enrolled, so that the sandbox has the key service and the **Export enrolment** button.

### 2. Register an application for the key service (optional)

Skip this step if you only use enrolment files.

1. In the Azure portal, **Microsoft Entra ID > App registrations > New registration**, for example `D365 EDS key service`. Single tenant. No redirect URI.
2. **Certificates & secrets > New client secret**. Copy the secret value.
3. Copy the **Application (client) ID** and the **Directory (tenant) ID**.

No API permissions are needed; D365 checks the application itself.

### 3. Allow the application in the sandbox

In the sandbox:

1. **System administration > Users > Users**: create a user for the application, for example `EDSKeyService`, and give it only the role **Environment data setup key service** (`OLK_EdsKeyService`).
2. **System administration > Setup > Microsoft Entra ID applications**: add the client ID, a name, and the user from step 1.

Make the same two entries **in the master too**. A refresh replaces the sandbox's database with the master's, including these two tables; if the entries exist in the master, the sandbox keeps them after every refresh.

If the user is disabled after a refresh, enable it again in the sandbox.

The role grants only the key service. The service returns the public key and the locked private key, which are useless outside the sandbox.

### 4. Add the sandbox to Environments in the master

In the master, **System administration > Setup > Environment data setup > Environments**, **New**:

| Field | Example | Required |
| --- | --- | --- |
| Environment id | `UAT` | Yes |
| Description | `User acceptance test` | No |
| Environment URL | `https://contoso-uat.sandbox.operations.dynamics.com` | Yes |
| Client ID | `0f6c3c8e-1d2b-4b7a-9a51-2f0d5c6e7a10` | No, only for Fetch key |
| Tenant ID | `contoso.onmicrosoft.com` or the tenant GUID | With Client ID |
| Client secret | the secret from step 2 | With Client ID |

The client secret is encrypted for the environment where it is entered (the master) and is never shown. Copied to a sandbox, it is unreadable there, which is fine because only the master calls the key service.

The URL identifies the environment: only its host name counts, and two environments cannot have the same host. Give the master its own record with its own URL too.

### 5. Get the sandbox's key

Select the sandbox's record and click **Fetch key**.

- **The key service answers:** the public key, the locked private key and the fingerprint are stored, and *The key of environment UAT was stored. Fingerprint ...* is shown. **Key status** shows *Enrolled*.
- **The key service cannot be called** (no client ID, the application is not allowed in the sandbox, the sandbox is stopped, or the network blocks the call): the reason is shown, and the sandbox's Environments page opens in a new browser tab. Continue with the enrolment file below.

#### Enrolment file

1. In the sandbox's Environments page (the tab that opened), click **Export enrolment**. The browser downloads `EDS-enrolment-<host>.zip`.
2. Back in the master, select the sandbox's record, click **Import enrolment** and upload the ZIP file.

The ZIP file contains:

| File | Content |
| --- | --- |
| `enrolment.txt` | What **Import enrolment** reads: host name, fingerprint, creation time, public key and locked private key. |
| `public-key.xml` | The public key, as RSA key XML. |
| `private-key.locked.txt` | The private key, locked with the sandbox's certificate, as base64. It cannot be unlocked anywhere else. |
| `README.txt` | What the file is and how to import it. |

**Import enrolment** rejects a file whose host is not the record's URL, or whose public key does not match its fingerprint.

To check that you enrolled the right key, compare the **Key fingerprint** in the master with the one in the sandbox: in the sandbox, its own record shows the same fingerprint after the next refresh, and `README.txt` shows it right away.

## Entering encrypted values

In the master, open [Data setup](data-setup.md) for the sandbox, add a line with **Encrypted field** = Yes and the **Edit method name**, then type the value in **Field value**. It is encrypted as you leave the field; the form shows `********`.

- The sandbox must have a key first, otherwise *Environment UAT has no encryption key* is shown.
- If you change the line's environment, company, table, edit method or record, the encrypted value is cleared and must be typed again.
- To change a value, type the new one over the mask. Clearing the field clears the value.

## After the refresh

In the sandbox, run [Execute environment data setup](execute.md) for its own record, as before. The encrypted lines are decrypted and written; the log shows them without the value.

If an encrypted line fails, the log says why:

| Message | Meaning and fix |
| --- | --- |
| *The setup of environment UAT can be executed only in ...* | You are executing another environment's setup. Select the record of this environment. |
| *The key of environment UAT cannot be unlocked here.* | The key was not created by this environment, or its certificate changed. Fetch or import the key again in the master, and type the encrypted values again. |
| *The value cannot be decrypted.* | The value was encrypted for another key or line, or the cipher text was changed. Type the value again in the master. |

Lines that are not encrypted are not affected and run as before.

## Key status

The **Key status** column of Environments shows:

| Status | Meaning |
| --- | --- |
| No key | Fetch or import the key. |
| Enrolled | The record has a key. Shown for every environment other than the current one. |
| Usable here | The record is the current environment and its key unlocks here. |
| Cannot be unlocked here | The record is the current environment, but the key does not unlock. Enrol the environment again. |

## Replacing a key

**Fetch key** or **Import enrolment** with a different key asks before replacing it, because the existing encrypted values of the environment can only be decrypted with the old key. If you confirm, they are cleared and must be typed again.

A sandbox keeps the same key across refreshes: after a refresh it finds its key in its own record, which came from the master. A key is new only when the sandbox was never enrolled, or when its key can no longer be unlocked.

## Values entered before encryption

Encrypted lines entered before this version hold the value in plain text. They still run, but the value is readable in a database dump. Select the environment and click **Encrypt plain values** once the environment has a key; the values are encrypted and the plain text is removed. Old database backups still contain the plain values, so change those secrets afterwards.

## The key service

| | |
| --- | --- |
| Service group | `OLK_EdsServices` |
| Service | `OLK_EdsKeyService` |
| Operation | `getEnrolment`, no parameters |
| URL | `https://<sandbox>/api/services/OLK_EdsServices/OLK_EdsKeyService/getEnrolment` |
| Role | Environment data setup key service (`OLK_EdsKeyService`) |
| Returns | The enrolment text (the content of `enrolment.txt`) as URL-safe base64 |

Example call from PowerShell, to test the application registration without the master:

```powershell
$tenant   = "contoso.onmicrosoft.com"
$clientId = "0f6c3c8e-1d2b-4b7a-9a51-2f0d5c6e7a10"
$secret   = "<client secret>"
$sandbox  = "https://contoso-uat.sandbox.operations.dynamics.com"

$token = (Invoke-RestMethod -Method Post `
    -Uri "https://login.microsoftonline.com/$tenant/oauth2/v2.0/token" `
    -Body @{ grant_type = "client_credentials"; client_id = $clientId; client_secret = $secret; scope = "$sandbox/.default" }).access_token

$response = Invoke-RestMethod -Method Post -ContentType "application/json" -Body "{}" `
    -Headers @{ Authorization = "Bearer $token" } `
    -Uri "$sandbox/api/services/OLK_EdsServices/OLK_EdsKeyService/getEnrolment"

# Decode the URL-safe base64 to see the enrolment text.
$b64 = $response.Replace('-', '+').Replace('_', '/')
$b64 += '=' * ((4 - $b64.Length % 4) % 4)
[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($b64))
```

The first call creates the sandbox's key; later calls return the same key.

## What this protects against, and what it does not

| Threat | Protected |
| --- | --- |
| Reading a sandbox's secrets in the master's forms | Yes. Only the mask is shown. |
| Reading them from a database dump or backup of the master | Yes. Only cipher text and locked keys are stored. |
| Reading them in another sandbox or a development box restored from a copy | Yes. The key does not unlock there. |
| Redirecting an encrypted value to a visible field by editing the line | Yes. The value is bound to its line. |
| A user of the master who types the value | No. Whoever types it knows it. |
| An administrator of the sandbox itself | No. The sandbox can decrypt its own secrets by design, and its administrators can deploy code there. |
| Someone in the master replacing the sandbox's public key with their own | Partly. Values entered afterwards would be encrypted for them. The fingerprint is shown, and replacing a key needs the key management privilege. Compare fingerprints after a change. |

## Technical details

| | |
| --- | --- |
| Key pair | RSA 3072, `RSACng` |
| Value encryption | Random 256 bit key per value. AES-256-CBC with PKCS7, and HMAC-SHA256 over the cipher text and the line binding (encrypt then MAC). The random key is encrypted with RSA-OAEP-SHA256. |
| Cipher text | `OLK1:<encrypted key>:<IV>:<cipher text>:<MAC>`, each part base64, in `OLK_EnvironmentDataSetupTrans.CipherText`. `Value` stays empty. |
| Private key at rest | Locked with `Global::editEncryptedField` (platform encryption of the environment), in `OLK_EnvironmentDataSetupTable.LockedPrivateKey` and, before the first refresh, in `OLK_EnvironmentDataSetupKey`. |
| Classes | `OLK_EnvironmentDataSetupCrypto` (cryptography), `OLK_EnvironmentDataSetupKeyManager` (keys, service call, ZIP files), `OLK_EnvironmentDataSetupEnrolment` (enrolment text), `OLK_EnvironmentDataSetupKeyService` (key service), `OLK_EnvironmentDataSetupKeyAction` (form buttons). |
