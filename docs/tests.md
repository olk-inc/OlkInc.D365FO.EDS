[← Return to README](../README.md)

# Tests

The tests are in the model **OlkInc-D365FO-EDS-Test** (`Metadata/OlkInc-D365FO-EDS-Test`), which depends on OlkInc-D365FO-EDS and ApplicationSuite. Do not deploy it to production.

## Running them

- **From the web client:** open `https://<environment>/?mi=SysClassRunner&cls=OLK_EnvironmentDataSetupTestJob`. `OLK_EnvironmentDataSetupTestJob` runs every test method with its own `setUp` and `tearDown` and reports each one in the infolog (*Passed ...* or *FAILED ...: reason*), then a total.
- **From Visual Studio:** Test Explorer.

The tests commit their data, so you can review it in the forms afterwards. They use the environments `DEV`, `TEST`, `EDSLOG`, `EDSENC` and `EDSENC2`, and customer groups starting with `EDS`.

## Test classes

| Test class | What it checks |
| --- | --- |
| `OLK_EnvironmentDataSetupTest` | [Data setup](data-setup.md) lines give customer group `EDSTEST` a different name in `DEV` and `TEST`; another environment's lines are not applied; lines entered by table and field name work; invalid lines are refused; enum values entered as a symbol are stored as numbers. |
| `OLK_EnvironmentDataSetupSqlTest` | Customer group `EDSSQL` is created with `insert()`, renamed by an UPDATE [SQL job](sql-jobs.md) and removed by a DELETE SQL job, in DEV and in TEST. A delete that finds nothing logs 0 rows. Inactive jobs, jobs with Execute SQL = No, and statements other than a single UPDATE, INSERT or DELETE do not run. |
| `OLK_EnvironmentDataSetupCodeJobTest` | [Code jobs](code-jobs.md): Create code jobs (inactive, no duplicates, environment required), Activate all, Deactivate all, Delete all and Delete; only code job methods are accepted; inactive jobs and Execute code = No do not run; the sample code jobs create 5 customer groups (repeatably) and schedule the entity list refresh. |
| `OLK_EnvironmentDataSetupDefaultValuesTest` | [Default values](default-values.md) are created, lists are split and trimmed, a missing value gives an empty list, and a code job follows a changed default value. |
| `OLK_EnvironmentDataSetupPersonalizationTest` | The [Personalize pop-up](personalization.md) proposes the master environment and the control's label; long labels are cut; only one master is allowed. |
| `OLK_EnvironmentDataSetupEncryptionTest` | [Encrypted values](encryption.md): marking a plain line as encrypted, and writing the value to a normal field; encrypt and decrypt; another line, another key or a changed cipher text fails; the private key locks and unlocks here; the key of this environment stays the same; enrolments survive the text, service and ZIP formats, and a changed one or one for another URL is refused; an encrypted line stores only cipher text; executing it here writes the value and does not log it; executing it for an environment with another URL fails. |
| `OLK_EnvironmentDataSetupLogTest` | Every data line, active code job and active SQL job is [logged](log.md) once; failures are logged as Error with the reason and do not stop the rest; the log form shows the entries. |

## Supporting classes

| Class | Role |
| --- | --- |
| `OLK_EnvironmentDataSetupTestHelper` | Creates the test environments, executes the setup, and finds log entries. |
| `OLK_EnvironmentDataSetupTestJob` | The web client runner. |
| `OLK_EnvironmentDataSetupTestResult` | Collects the message of the first failed assertion for the runner. |
| `OLK_EnvironmentDataSetupExecuteCode_Sample` | The sample code jobs; see [Writing a code job](writing-code-jobs.md#the-sample-class). |
