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
| Environment default values | Holds the lists that code jobs read, for example `EnableUsersList` and `EnableBatchJobsList`. |
| Environment data setup log | Records the result of each line. |

## Adding data setup lines

Open the personalization pop-up on any field (right-click > Personalize). Pick the environment, enter a description, and select **Create environment data**. This adds the field and its current value to the data setup. You can then change the value in the Data setup form.

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

## Security

| Role, duty and privilege | Access |
| --- | --- |
| `OLK_EdsView` | View |
| `OLK_EdsMaintain` | Maintain and execute |

The **OLK_EdsConfigKey** configuration key switches the feature on or off.

## Tests

`OLK_EnvironmentDataSetupTest` (model OlkInc-D365FO-EDS-Test) runs the setup end to end. It creates the customer group `EDSTEST` and the environments `DEV` and `TEST`, each with a data setup line that gives the customer group a different name. It then executes the data setup for DEV and for TEST and checks that the customer group gets that environment's name and that the run is logged. The test data is kept, so it can be reviewed in the forms afterwards.
