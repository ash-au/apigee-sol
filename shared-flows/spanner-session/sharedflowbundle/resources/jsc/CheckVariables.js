
// Check if required variables are present
var spannerString = context.getVariable('gcp.spannerstring');
var gcpToken = context.getVariable('private.gcp.access_token');

if (!spannerString) {
  context.setVariable('gcp.spanner.error_message',
    'Spanner project, instance and database information not present');
}

if (!gcpToken) {
  context.setVariable('gcp.spanner.error_message',
    'GCP Access Token is not provided');
}