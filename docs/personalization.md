[← Return to README](../README.md)

# Adding data setup lines from any form

The model extends the standard Personalize pop-up (form `FormControlQuickPersonalization`) with a group that adds a field to the [data setup](data-setup.md) in two clicks.

## How to use it

1. Open the form and record whose value should differ per environment, for example the parameters form that holds a service URL.
2. Right-click the field and select **Personalize**.
3. In the environment data setup group:
   - **Environment id** is proposed as the [master environment](environments.md). Change it to the environment the value is for.
   - **Description** is proposed as the field's label, cut to the length of a description. Change it if needed.
4. Select **Create environment data**.

The field and its current value are added to the data setup of that environment, and the message *Field X was added to the data setup for environment Y* is shown. Open [Data setup](data-setup.md) to change the value to what the environment needs.

If the same field of the same record is already in the data setup of that environment, its value is replaced with the current value.

## When the group is shown

The group is shown only when all of these hold:

- the control is bound to a data source;
- the configuration key **OLK Environment data setup** (`OLK_EdsConfigKey`) is on;
- the user has access to the Data setup menu item (see [Security](security.md)).

## Encrypted fields

Encrypted fields are shown through edit methods. For such a control the line is created as an encrypted line with the edit method's name and no value; enter the value in the Data setup form.

If the control is bound neither to a table field nor to an edit method, or no record is selected, the button reports *The control is not bound to a table field or an edit method.*

## Implementation

| Object | Role |
| --- | --- |
| `FormControlQuickPersonalization.OLK_Eds_Extension` (form extension) | Adds the group with Environment id, Description and the Create environment data button. |
| `FormControlQuickPersonalization_Form_OLK_Eds_Extension` (class) | Shows or hides the group and fills in the defaults when the pop-up opens. |
| `OLK_EnvironmentDataSetupQuickPersonalizationHelper` | Handles the button and gives the default environment and description. |
| `OLK_EnvironmentDataSetupTrans::createFromControl` / `createTrans` | Create or update the data setup line. |
