# Oracle HCM — clone a worker from PROD to a lower environment

Give it a person name or work email. It finds the worker in PROD, builds a create payload from the live REST response, and posts it to the target pod via `POST /workers`.

## Setup

1. Import both files into Postman:
   - `Oracle_HCM_Worker_Clone.postman_collection.json`
   - `HCM_Clone_PROD_to_TARGET.postman_environment.json`
2. Select the environment and fill in `prod_host`, `prod_user`, `prod_pass`, `target_host`, `target_user`, `target_pass`.
3. Set `search_term` to a display name (`Jane Doe`) or a work email (`jane.doe@example.com`).
4. Run the collection top to bottom, or use the Collection Runner.

Clone the environment once per lower env (DEV1, TEST2, UAT) — only the three `target_*` values change.

## What each request does

| # | Request | Purpose |
|---|---------|---------|
| 01 | Find person in prod | Name → `DisplayName LIKE '%x%'`. Email → `emails.EmailAddress like 'x'`. Captures `workersUniqID` from the self link. |
| 02 | Get full worker from prod | Pulls expanded children and builds `create_payload`. All the transform logic lives in this test script. |
| 03 | Target duplicate check | Idempotency gate on work email. Halts the run if the worker already exists. |
| 04 | Target reference code check | Confirms a referenced code exists in the target before creating. Ships pre-wired to the assignment's `JobCode`. |
| 05 | Create worker in target | `POST /workers` with the built payload. Appends a prod → target mapping to `clone_log`. |
| 06 | Verify worker in target | Reads it back and prints the running clone log. |
| 07 | Check user account in target | `POST /workers` may have already auto-provisioned an account. If so, captures its GUID and skips 08. |
| 08 | Create user account in target | `POST /userAccounts` with the new `PersonId`. Captures GUID, UserId, Username. |
| 09 | Resolve role code in target | `rolesLOV` turns a role code into the numeric `RoleId` that role assignment needs. |
| 10 | Assign role to user account | `POST /userAccounts/{GUID}/child/userAccountRoles`. Loops back to 09 until every code in `role_codes` is done. |
| 11 | Set login password | `POST .../action/updatePassword` with `{"pwd": "..."}` so you can sign in immediately. |
| 12 | Verify login readiness | Asserts the account exists, is not suspended, has at least one role, and is linked to the cloned person. |

## The transform rule that makes this work

Surrogate keys are pod-specific. `JobId 300000012345678` in PROD is a different job — or nothing at all — in DEV1. So request 02 strips every attribute matching `/(Id|Ids|UniqID)$/` and keeps the `*Code` / `*Name` equivalents, which the target pod resolves against its own reference data.

It also drops audit columns (`CreatedBy`, `LastUpdateDate`, `ObjectVersionNumber`, effective-dating internals) and nulls/empty strings, since HCM rejects several of those on create.

If you hit an attribute that only exists in `*Id` form with no code alternative, add it to `keep_ids` as a comma list and it will pass through untouched.

## Tuning knobs

| Variable | Default | Effect |
|---|---|---|
| `include_children` | `names,emails,legislativeInfo,workRelationships` | Which child collections get copied. Add `addresses`, `phones`, `nationalIdentifiers` as needed. |
| `expand_list` | includes `workRelationships.assignments` | Must expand anything you want in `include_children`. |
| `only_primary` | `true` | Copies just the primary work relationship and primary assignment. Set `false` to attempt all of them. |
| `copy_person_number` | `false` | Leave false if the target generates person numbers automatically. Set true only if the target uses manual numbering and you want the numbers to match. |
| `effective_start_date` | blank | Blank derives from the prod hire date. Set a date to force a different one. |
| `person_type_code` | blank | Injects `PersonTypeCode` onto the assignment if your pod requires it (e.g. `EMP`). |
| `allow_duplicate` | `false` | Set true to bypass the request 03 gate. |

## Reference data pre-flight

Request 04 is deliberately generic — set `ref_resource` and `ref_filter`, then duplicate it once per code you care about:

```
ref_resource = jobs           ref_filter = JobCode='SW_ENG_01'
ref_resource = grades         ref_filter = GradeCode='IC4'
ref_resource = departments    ref_filter = DepartmentName='Supply Chain'
ref_resource = locations      ref_filter = LocationCode='ATL_HQ'
```

Confirm resource names against your own pod before relying on them:

```
GET {{target_host}}/hcmRestApi/resources/{{api_version}}/workers/describe
```

The `describe` action lists the real attribute names, queryable fields, and child resources for your release. Worth doing once per pod upgrade.

## Making the cloned worker able to log in

A worker record and a user account are two separate objects in HCM with no automatic link. `POST /workers` succeeding does not mean anyone can sign in. Requests 07 through 12 close that gap.

Set two environment values before running them:

| Variable | Example | Notes |
|---|---|---|
| `role_codes` | `ORA_PER_EMPLOYEE_ABSTRACT` | Comma-separated. Requests 09 and 10 loop over the whole list automatically in the Collection Runner. |
| `new_password` | a throwaway lower-env password | Marked secret. Leave blank to skip request 11 and use the reset-password flow instead. |
| `target_username` | blank | Blank lets HCM derive the username from the work email. Set it only if your lower env uses a different convention. |

The chain runs: check for an existing account → create one if absent → resolve each role code to a `RoleId` → assign it → set a password → verify.

### Password: set it or email a reset link

Request 11 sets a known password directly, which is what you usually want in a lower env. The alternative, if your security standard forbids setting passwords via API, is the reset action — same GUID, no body:

```
POST {{target_host}}/hcmRestApi/resources/{{api_version}}/userAccounts/{{target_user_guid}}/action/resetPassword
Content-Type: application/vnd.oracle.adf.action+json
```

That emails the user a reset link, which in a lower env means it goes to whatever address the notification config points at — often nowhere. Check where lower-env notifications land before relying on it.

### If your lower env is federated

If the target pod authenticates through OCI IAM, IDCS, or an external IdP rather than local Fusion credentials, request 11 sets a password that the login page never consults. The account and roles still matter, but the credential has to be created on the IdP side. Worth confirming which way your DEV and TEST pods are configured — they're often not the same as prod.

## Known failure modes

**Missing reference data.** The most common cause of a failed or wrong create. The worker payload references legal employer, business unit, job, grade, position, department, location, and payroll. If any code is absent in the target, the create fails or silently lands with a default. Run request 04 for each one before trusting the result.

**Person number won't match.** Unless `copy_person_number=true` and the target uses manual numbering, the clone gets a new number. `clone_log` keeps the prod → target mapping; export it if downstream test data depends on the number.

**Multiple matches.** If a name search returns more than one worker, request 01 prints the candidates to the console and halts. Re-run with the exact work email.

**PER-1532373 on user account create.** The enterprise User Account Creation option is suppressing REST-driven account creation. Fix it in Setup and Maintenance → Manage Enterprise HCM Information → User and Role Provisioning. Request 08 detects this error code and prints the path to the console.

**Role missing from `rolesLOV`.** `rolesLOV` only returns roles assignable under your role provisioning rules. If a code isn't there, the provisioning rules are what need changing — the role exists, your API user just isn't allowed to grant it.

**PER_USER_ACC_UPDATE_INVALID on password set.** The account isn't linked to a person record yet. Re-run request 07 to pick up the link, then retry 11.

**Account created but no roles.** Request 12 fails on the role assertion. The user can sign in and will see an empty home page. Either add the right code to `role_codes`, or trigger autoprovisioning: `POST /userAccounts/{GUID}/action/autoprovisionRoles`.

**Future-dated or terminated workers.** A worker whose record is future-dated or already terminated in prod will produce a payload with dates the target may reject. Set `effective_start_date` explicitly in those cases.

## One flag worth raising

You chose to copy prod data as-is, which is the right call for fidelity — cloned test data that has been mangled by masking often fails to reproduce the bug you were chasing. But this does move real names, emails, and potentially dates of birth and national identifiers into a lower environment, where the access control is usually looser and the refresh cadence is unpredictable.

Two cheap mitigations that don't cost you fidelity:

- Leave `nationalIdentifiers` out of `include_children` (it already is by default). That's the highest-sensitivity field in the payload and test scenarios almost never need it.
- Keep `clone_log` exports out of shared drives and tickets, since it pairs real names with person numbers.

If your account has a data privacy standard for non-production, it's worth a quick check before this goes into regular use.
