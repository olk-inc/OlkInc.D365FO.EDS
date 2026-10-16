# Environment data setup – screenshot steps

Captured on 2026-10-15 in the development environment, viewport 1366x768.
Red circles = step numbers, red frames = the control used in that step. Numbers continue across the images of one sequence.

## 1. Create environment data from the Personalize pop-up

### personalize-1-context-menu.png
1. Open **Customer groups** (`mi=CustGroup`) and click the row **EDSTEST** to select it.
2. Right-click the **Description** field of that row.
3. Choose **Personalize: Description** in the context menu.

### personalize-2-popup.png
4. The Personalize pop-up opens with focus in **Label**.
5. Press **Tab** until focus reaches **Environment id** in the lower **Data setup** group. On this VM that takes **14 times**: the Lasernet "Add to report" link and the legacy MSA-EnvironmentDataSetup group (upper "Data setup" with "Use keyboard to choose Id") add extra stops. With only OLK EDS installed it is 9 times. Clicking the field works too.
6. Type the environment id, e.g. `DEV`, then press **Tab** (don't press Enter, see note).
7. In **Description**, type a short description of the line, e.g. `Customer group name`.
8. Press **Tab** to move focus to **Create environment data**, then press **Enter** (or click the button).

> Note: the lookup list opens by itself when you type in Environment id. If you choose the value from that list (Enter or click), the Personalize pop-up collapses to an empty frame. Typing the id and pressing Tab avoids this.

### personalize-3-info-message.png
9. The message bar confirms: *"Field Name was added to the data setup for environment DEV."* If the line already exists, you get *"Field Name on this record is already in the data setup for environment DEV."* and no duplicate is created.

### personalize-4-data-setup.png
10. Open **Data setup** (`mi=OLK_EnvironmentDataSetupTrans`). The new line (DEV / Customer group name / CustGroup / Name) is in the grid.
11. The header shows the environment, description, company, table, field and the stored field value (`EDS test customer group TEST`).

## 2. environments.png – Environments (`mi=OLK_EnvironmentDataSetupTable`)
1. **New**: add an environment (Environment id, Description).
2. **Data setup**: open the data lines of the selected environment.
3. **Code jobs**: open the code jobs of the selected environment.
4. **SQL jobs**: open the SQL jobs of the selected environment.
5. **Environment data setup log**: open the execution log.
6. **Execute environment data setup**: run the setup for the selected environment (see execute.png).
7. **Master environment**: marks the master environment (DEV here). Only one environment can be the master.

## 3. data-setup.png – Data setup details (`mi=OLK_EnvironmentDataSetupTrans`)
1. Click **Edit** (it turns into **Save** while editing, as shown).
2. **Table name**: select the table (lookup), e.g. `CustGroup`.
3. **Field name**: click the field and press **Alt+Down** (or click the arrow) to open the lookup.
4. The lookup lists the table's fields with their labels. Pick one with the arrow keys + Enter or a click.
5. **Field value**: type the value to write in the target environment.
6. **Set enum value**: picks the value from the enum's elements. It is only enabled when the selected field is an enum, so it is greyed out here for the string field `Name`.

## 4. Code jobs (`mi=OLK_EnvironmentDataSetupCode`)

### code-jobs-1-form.png
1. Click **Create code jobs**.

### code-jobs-2-dialog.png
2. **Environment id**: type or choose the environment, e.g. `DEV` (focus starts here).
3. Press **Tab** to **Company** and type the company, e.g. `USMF`.
4. Click **OK** to create the missing code jobs (inactive). For the screenshot I clicked **Cancel**, because DEV already has its code jobs.

### code-jobs-3-activate.png
5. Select a code job line in the list.
6. **Active**: turn on the jobs that should run for this environment (Edit first).
7. **Delete all**: deletes all code jobs of the environment. I did not click it.
8. **Activate all**: sets Active = Yes on all code jobs of the environment.
9. **Deactivate all**: sets Active = No on all code jobs of the environment.

## 5. execute.png – Execute environment data setup
The action menu item can't be opened by URL (`mi=OLK_EnvironmentDataSetupExecute` gives "No object specified on menu item"), so open it from **Environments**:
1. Select **DEV** in Environments and click **Execute environment data setup**.
2. **Environment id**: `DEV` (pre-filled from the selected line).
3. **Execute data**: Yes, to apply the Data setup lines.
4. **Execute code**: Yes, to run the active code jobs.
5. **Execute SQL**: Yes, to run the active SQL jobs.
6. **Batch processing**: optional, to run it in batch (the batch service is stopped on this VM).
7. **OK** starts it. For the screenshot I clicked **Cancel**.

## 6. log.png – Environment data setup log (`mi=OLK_EnvironmentDataSetupLog`)
1. Select a log entry (newest first).
2. **Log type**: Data, Code or SQL.
3. **Status**: e.g. Error.
4. **Error** FastTab: the error text, e.g. "Record 1 in table CustGroup was not found."

## 7. Default values and SQL jobs

### default-values.png (`mi=OLK_EnvironmentDataSetupDefaultValues`)
1. **New**: add a default value.
2. **Default value id**: the key that code jobs read, e.g. `EnableUsersList`.
3. **Value type**: String, Integer, …
4. **Field value**: the value itself.

### sql-jobs.png (`mi=OLK_EnvironmentDataSetupSQL`)
1. **New**: add an SQL job.
2. **Environment id**, **Company**, **SQL job id** identify the job.
3. **Active**: only active jobs run.
4. **SQL statement**: the statement to run. `%DataAreaId%` is replaced with the company.
