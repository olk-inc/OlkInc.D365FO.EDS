[← Return to README](../README.md)

# Environment data setup log

**System administration > Setup > Environment data setup > Environment data setup log** (form and table `OLK_EnvironmentDataSetupLog`)

Every [execution](execute.md) writes one log line per data setup line, per active code job and per active SQL job it ran. The form is read only and shows the newest entries first. Open it from [Environments](environments.md) to see one environment's log.

## Fields

| Field | Data line | Code job | SQL job |
| --- | --- | --- | --- |
| Environment id | The executed environment | ← | ← |
| Log type | Data | Code | SQL |
| Log id | RecId of the data setup line | `ClassName.methodName` | SQL job id |
| Description / field / method | Line description | Method name | Job description |
| Company | Company of the line | Company of the job | Company of the job |
| Table id, Table name, Field id, Field name, Record id | The updated record and field | | |
| Original value | Value before the update | | |
| Field value | Value written | | Number of rows affected |
| Status | OK or Error | OK or Error | OK or Error |
| Error text | Error and infolog messages of a failed line | ← | ← |
| Created date and time, Created by | When and by whom it ran | ← | ← |

Values of encrypted fields are not logged.

## Typical errors

| Message | Cause |
| --- | --- |
| Record R in table T was not found. | The data setup line points at a RecId that does not exist in its company. |
| Table T, field F: validation failed, so the record was not updated. | The table's `validateField` or `validateWrite` refused the value. The messages before it say why. |
| Fields of type X are not supported. | The field type cannot be stored as text. |
| Method M on class C is not an environment data setup code job. | The method lost its attribute, gained parameters or was removed. |
| Only a single UPDATE, INSERT or DELETE statement is allowed. | The SQL job holds another kind of statement or more than one. |
