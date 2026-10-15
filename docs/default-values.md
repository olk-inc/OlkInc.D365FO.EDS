[← Return to README](../README.md)

# Environment default values

**System administration > Setup > Environment data setup > Environment default values** (form and table `OLK_EnvironmentDataSetupDefaultValues`)

Default values are named settings that [code jobs](code-jobs.md) read. A code job should not hard-code what it works on: it reads a default value instead, so an administrator can change its behaviour per environment without a deployment.

The values are not tied to an environment record. Each environment has its own database, so the values in UAT are the values UAT's code jobs read; change them there after a refresh, or set them with a [data setup](data-setup.md) line in the master environment.

## Fields

| Field | Description |
| --- | --- |
| Default value id | The name a code job looks the value up by, up to 30 characters. Unique. |
| Description | What the value is for. |
| Value type | String, Integer, Real, Date, Enum or Date and time. Describes the value for the reader; code jobs read the value as text. |
| Field value | The value. Lists are comma separated. |

## Values in the model

| Id | Read by |
| --- | --- |
| `EnableUsersList` | `enableUsersList`: the user ids to enable, for example `admin, jsmith`. |
| `EnableBatchJobsList` | `enableBatchJobsList`: the batch job ids or descriptions to set to Waiting. |

They are created, empty, when the form is opened, if they do not exist yet.

The test model adds `SampleCustGroupCount` (Integer, default `5`) and `SampleCustGroupPrefix` (String, default `EDSSMP`), read by the sample `createSampleCustGroups`. The tests create them; see [Writing a code job](writing-code-jobs.md#the-sample-class).

## Reading a value in X++

| Call | Returns |
| --- | --- |
| `OLK_EnvironmentDataSetupDefaultValues::find(id).Value` | The value as text; empty when the id does not exist. |
| `OLK_EnvironmentDataSetupDefaultValues::valueList(id)` | A `List` of strings: the value split on commas, each item trimmed, empty items left out. Empty when the id does not exist or the value is blank. |
