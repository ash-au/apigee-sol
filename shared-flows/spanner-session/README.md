# spanner-session
This shared flow can be used to get or create a session to spanner from Apigee.
This is dependent on Apigee devrel's [Service Account - Authentication Share Flow](https://github.com/ash-au/devrel/tree/main/references/gcp-sa-auth-shared-flow).
Deploy and invoke that shared flow before invoking this shared flow in your API Proxy.
In current version all spanner sessions are created with lable `test`.
TODO: Add filter as input variable
TODO: Create 1:1 mapping between Apigee App and Spanner Session

## Shared Flow usage from within an API proxy

1. In your Apigee flow, make sure you have invoked the Service Account Auth shared
   flow which will populate the varaibel `private.gcp.access_token`

2. Also populate variable `gcp.spannerstring` which should follow the same syntax as 
   described [here](https://cloud.google.com/spanner/docs/reference/rest/v1/projects.instances.databases.sessions/create) i.e.
   it should look like this `projects/{gcp.project}/instances/{gcp.instance}/databases/{gcp.db}/sessions`.
   It should look like this in an AssignedMessage policy
   
   ```
    <AssignVariable>
        <Name>gcp.spannerstring</Name>
        <Template>projects/{gcp.project}/instances/{gcp.instance}/databases/{gcp.db}/sessions</Template>
    </AssignVariable>
   ```

3. If there are no errors, spanner session will be available in variable `gcp.spanner.session` on 
   completion of shared flow
