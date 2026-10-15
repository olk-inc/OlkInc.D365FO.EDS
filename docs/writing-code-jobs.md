[← Return to README](../README.md)

# Writing a code job

This is the developer guide for adding your own [code jobs](code-jobs.md). The same guide is in the header of `OLK_EnvironmentDataSetupExecuteCode_Sample` in the test model, which you can copy into your own model as a starting point.

## Steps

1. In your own model, reference the **OlkInc-D365FO-EDS** package.
2. Create a class that extends `OLK_EnvironmentDataSetupExecuteCode` **directly**. Only direct subclasses are found by Create code jobs.
3. Add a public instance method without parameters and decorate it with `[OLK_EnvironmentDataSetupAttribute('What the job does')]`. The text becomes the code job's description. Methods without the attribute, with parameters, or that are static are not code jobs.
4. Build the model. The method is now available to **Create code jobs**.
5. In the [Code jobs](code-jobs.md) form, run **Create code jobs** for the environment and company, and activate the new job.

```xpp
class MyEnvironmentDataSetupExecuteCode extends OLK_EnvironmentDataSetupExecuteCode
{
    [OLK_EnvironmentDataSetupAttribute('Point the integration at the test endpoint.')]
    public void setIntegrationEndpoint()
    {
        str url = OLK_EnvironmentDataSetupDefaultValues::find('MyIntegrationUrl').Value;
        // ... write url where it belongs
    }
}
```

## Rules

- **Company.** The method runs in the company of the code job; the framework switches company for you.
- **Environment.** `this.parmEnvironmentId()` returns the environment being executed, so one method can behave differently per environment.
- **Errors.** Each code job runs on its own. When it throws an error, the error and the infolog messages are written to the [log](log.md) with status Error, and the other code jobs still run. Use `ttsbegin`/`ttscommit` inside the method when it writes several records that belong together.
- **Run it again safely.** The setup is executed after every refresh, and often more than once. Check whether a record exists before you create it.
- **No hard-coded settings.** Read values from [Environment default values](default-values.md), so an administrator can change the behaviour per environment without a deployment. For a comma separated list use `OLK_EnvironmentDataSetupDefaultValues::valueList(id)`, which returns the items trimmed and without empty ones; for a single value use `OLK_EnvironmentDataSetupDefaultValues::find(id).Value`.

## How the framework finds and runs code jobs

| Member | Role |
| --- | --- |
| `OLK_EnvironmentDataSetupAttribute` | Marks a method as a code job and carries its description. |
| `OLK_EnvironmentDataSetupExecuteCode::codeJobAttribute` / `isCodeJobMethod` | A method is a code job when it is an instance method of a subclass, has no parameters and has the attribute. |
| `OLK_EnvironmentDataSetupExecuteCode::createCodeJobs` | Walks the direct subclasses and creates an inactive code job for each code job method that has none for the environment and company. Returns the number created. |
| `OLK_EnvironmentDataSetupExecuteCode::runMethod` | Creates an instance of the class, sets the environment id and calls the method. Refuses methods that are not code jobs. |

## The sample class

`OLK_EnvironmentDataSetupExecuteCode_Sample` (test model) shows both rules in practice:

| Method | What it does |
| --- | --- |
| `createSampleCustGroups` | Creates customer groups `EDSSMP01` to `EDSSMP05` in the company of the code job, leaving existing groups as they are. The number and prefix come from the `SampleCustGroupCount` and `SampleCustGroupPrefix` default values. |
| `refreshDataEntityList` | Schedules **Refresh entity list** of Data management in batch, as the button in Data management > Framework parameters > Entity settings does. It only schedules the refresh, so the setup does not wait for it, and schedules nothing when a refresh is already waiting or running. |

`createSampleDefaultValues` creates the two sample default values when they do not exist; the tests call it.
