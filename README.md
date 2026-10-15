# OlkInc-D365FO-EDS

Environment data setup for Dynamics 365 Finance and Operations. After a database is copied from one environment to another (for example PROD to UAT), it writes the environment specific values back: field values, code jobs and SQL jobs. Every run is logged.

The model is in `Metadata/OlkInc-D365FO-EDS` and uses the standard PackagesLocalDirectory layout. It depends on ApplicationPlatform and ApplicationFoundation. The tests are in a separate model, `Metadata/OlkInc-D365FO-EDS-Test`, which also depends on ApplicationSuite.

## Where to find it

System administration > Setup > Environment data setup:

| Menu item | What it does |
| --- | --- |
| Execute environment data setup | Runs the setup for one environment: data, code jobs and/or SQL jobs. It can run in batch. |
| Environments | Lists the environments (PROD, UAT, ...). One environment can be marked as the master. |
| Data setup | Lists the field values to write. Each line names a record (company, table, RecId) and a field. |
| Code jobs | Lists the X++ methods to run. Use **Create code jobs** to add every available method. |
| SQL jobs | Lists single UPDATE, INSERT or DELETE statements. `%DataAreaId%` is replaced with the job's company. |
| Environment default values | Named settings that code jobs read, for example `EnableUsersList` and `EnableBatchJobsList`. |
| Environment data setup log | Records the result of each line. |

## Adding data setup lines

Open the personalization pop-up on any field (right-click > Personalize). The environment is proposed as the master environment and the description as the field's label; change them if needed and select **Create environment data**. This adds the field and its current value to the data setup. You can then change the value in the Data setup form.

Lines can also be entered directly in the Data setup form: pick the environment, enter the table name, select the field from the lookup, and enter the record id and the value. For enum fields, **Set enum value** lets you pick the value from the enum.

Values are stored as culture independent text:

| Type | Format |
| --- | --- |
| Date | `yyyy-mm-dd` |
| Date and time | ISO 8601 |
| Real | Dot as the decimal separator |
| Enum | The integer value or the symbol |

Encrypted fields cannot be assigned directly. They are written through an edit method on the table, named in **Edit method name**.

## Code jobs

To add a code job, add a public method without parameters to a direct subclass of `OLK_EnvironmentDataSetupExecuteCode`, and decorate it with `[OLK_EnvironmentDataSetupAttribute('description')]`. The model ships with these:

- `OLK_EnvironmentDataSetupExecuteCode_System`: `enableUsersAll` and `enableUsersList`.
- `OLK_EnvironmentDataSetupExecuteCode_Batch`: `enableBatchJobsEdsActive`, `enableBatchJobsAll` and `enableBatchJobsList`. They move batch jobs from Withhold to Waiting. **EDS active** is a new column on the batch job list.

## Code jobs form

- **Create code jobs** asks for the environment (proposed: the environment the form was opened for, the selected code job's environment, or the master environment) and the company (proposed: the current one). It adds an inactive code job for every code job method that has none yet, and says how many it added. Running it again adds no duplicates.
- **Activate all** and **Deactivate all** set or clear **Active** on every code job in the list, so filter the list first. **Delete all** deletes every code job in the list after you confirm.
- Fields: **Environment id**, **Company** (where the method runs), **Class name** and **Method name** (the code job), **Active** (only active code jobs run), **Description** (copied from the attribute).

The test model has a documented sample, `OLK_EnvironmentDataSetupExecuteCode_Sample`, to copy into your own model: `createSampleCustGroups` creates customer groups EDSSMP01-EDSSMP05, and `refreshDataEntityList` schedules **Refresh entity list** of Data management in batch.

## Environment default values

A code job should not hard-code what it works on. It reads named values from Environment default values instead, so an administrator can change its behaviour per environment without a deployment. Each value has an id, a description, a type and a value; lists are comma separated.

| Id | Read by |
| --- | --- |
| `EnableUsersList` | `enableUsersList`: the user ids to enable. |
| `EnableBatchJobsList` | `enableBatchJobsList`: the batch job ids or descriptions to set to Waiting. |
| `SampleCustGroupCount`, `SampleCustGroupPrefix` | The sample `createSampleCustGroups` (test model): how many groups and their id prefix. |

The first two are created when the form is opened; the sample values are created by the tests.

## Security

| Role, duty and privilege | Access |
| --- | --- |
| `OLK_EdsView` | View |
| `OLK_EdsMaintain` | Maintain and execute |

The **OLK_EdsConfigKey** configuration key switches the feature on or off.

## Tests

The tests are in model OlkInc-D365FO-EDS-Test. Run them all from the web client with `?mi=SysClassRunner&cls=OLK_EnvironmentDataSetupTestJob`, or from the Test Explorer. They commit their data, so it can be reviewed in the forms afterwards.

| Test class | What it checks |
| --- | --- |
| `OLK_EnvironmentDataSetupTest` | Data setup lines give customer group `EDSTEST` a different name in `DEV` and `TEST`. |
| `OLK_EnvironmentDataSetupSqlTest` | Customer group `EDSSQL` is created with insert(), renamed by an UPDATE SQL job and removed by a DELETE SQL job, in DEV and in TEST. Inactive jobs and statements other than a single UPDATE, INSERT or DELETE are not run. |
| `OLK_EnvironmentDataSetupCodeJobTest` | Create code jobs, Activate all, Deactivate all, Delete all and Delete; the sample code jobs create 5 customer groups and schedule the entity list refresh. |
| `OLK_EnvironmentDataSetupDefaultValuesTest` | Default values are created, lists are split and trimmed, and a code job follows a changed default value. |
| `OLK_EnvironmentDataSetupPersonalizationTest` | The Personalize pop-up proposes the master environment and the control's label. |
| `OLK_EnvironmentDataSetupLogTest` | Every data line, active code job and active SQL job is logged once, failures are logged as Error with the reason and do not stop the rest, and the log form shows the entries. |
