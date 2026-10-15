[← Return to README](../README.md)

# Code jobs

**System administration > Setup > Environment data setup > Code jobs** (form `OLK_EnvironmentDataSetupCode`, table `OLK_EnvironmentDataSetupCode`)

A code job is an X++ method that runs when the setup is [executed](execute.md) with **Execute code**. Use code jobs for setup that is not a single field value ([Data setup](data-setup.md)) or a single SQL statement ([SQL jobs](sql-jobs.md)): enabling users, releasing batch jobs, creating records, calling framework methods. To write your own, see [Writing a code job](writing-code-jobs.md).

## Fields

| Field | Description |
| --- | --- |
| Environment id | The [environment](environments.md) the code job belongs to. |
| Company | The company the method runs in. Empty means the company the setup is executed in. |
| Class id / Class name | The code job class. You can type the class name. |
| Method name | The code job method. |
| Active | Only active code jobs run. New code jobs are inactive, so nothing runs until you choose it. |
| Description | What the job does, copied from the method's attribute. You can change it. |

A code job is unique per environment, company, class and method. Saving a line whose method is not a code job method fails with *Method X on class Y is not an environment data setup code job.*

## Buttons

| Button | What it does |
| --- | --- |
| Create code jobs | Asks for the Environment id and the Company, then adds an inactive code job for every code job method that has none yet for them, and says how many it added. Running it again adds no duplicates. |
| Activate all | Sets **Active** on every code job in the list. |
| Deactivate all | Clears **Active** on every code job in the list. |
| Delete all | Deletes every code job in the list after you confirm. |

**Activate all**, **Deactivate all** and **Delete all** work on the list as it is filtered, so filter first (for example on Environment id) to change one environment only. The standard Delete button deletes the selected code job only. Create code jobs adds deleted jobs back, inactive.

**Create code jobs** proposes as environment: the environment the form was opened for (from [Environments](environments.md)), otherwise the selected code job's environment, otherwise the master environment. It proposes the current company.

## Code jobs in the model

### `OLK_EnvironmentDataSetupExecuteCode_System`

| Method | What it does |
| --- | --- |
| `enableUsersAll` | Enables every disabled user. |
| `enableUsersList` | Enables the disabled users whose ids are listed in the `EnableUsersList` [default value](default-values.md). |

### `OLK_EnvironmentDataSetupExecuteCode_Batch`

A database refresh typically leaves batch jobs on hold (Withhold). These code jobs move them back to Waiting through the standard batch status change, so its validations apply.

| Method | What it does |
| --- | --- |
| `enableBatchJobsEdsActive` | Sets the batch jobs on hold that are marked **Environment data setup active** to Waiting. |
| `enableBatchJobsAll` | Sets all batch jobs on hold to Waiting. |
| `enableBatchJobsList` | Sets the batch jobs on hold that are listed in the `EnableBatchJobsList` [default value](default-values.md) to Waiting. An item matches a batch job by its job id (RecId) or by its description. |

**Environment data setup active** (`OLK_EdsBatchActive`) is a field the model adds to the `BatchJob` table and a column it adds to the Batch jobs list (**System administration > Inquiries > Batch jobs**). Set it on the batch jobs that `enableBatchJobsEdsActive` should release.

The test model adds two more, in `OLK_EnvironmentDataSetupExecuteCode_Sample`; see [Writing a code job](writing-code-jobs.md#the-sample-class).

## At execution

Every active code job of the environment runs in its company and writes one line to the [log](log.md): type Code, id `ClassName.methodName`, status OK or Error with the error text. A failing code job does not stop the others.
