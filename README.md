# Amazon Connect Sample Project

Terraform stack that provisions an Amazon Connect contact center and a
minimal sample application built around it.

## What gets created (`terraform/`)

- `aws_connect_instance` — the Connect instance (CONNECT_MANAGED identity,
  inbound/outbound calling, Contact Lens, and contact flow logs enabled).
- S3 bucket for call recordings and chat transcripts (encrypted, private).
- `aws_connect_queue`, `aws_connect_routing_profile`, and a default admin
  `aws_connect_user` (soft phone) with the instance's built-in **Admin**
  security profile attached (see "Gotchas" below).
- A Lambda function (`lambda/customer_lookup`) that mocks a CRM lookup by
  caller phone number and is associated with the instance.
- A sample inbound contact flow (`contact_flows/sample_inbound_flow.json.tpl`)
  that: greets the caller → invokes the Lambda → branches on a `VIP`
  attribute → sets the working queue → transfers to the queue.
- Optional: claim a phone number (`var.claim_phone_number = true`) — this
  incurs cost and requires manual association to the flow in the console.

## Sample application (`app/web/`)

A static single-page app using the [Amazon Connect Streams](https://github.com/amazon-connect/amazon-connect-streams)
JS library. It embeds the Contact Control Panel (CCP) so an agent can log
in and take calls in the browser, and displays the customer attributes
returned by the `customer_lookup` Lambda for the active contact.

To use it:
1. `terraform apply` and note the `connect_instance_access_url` output.
2. Approve your app's origin so the CCP can be embedded in an iframe
   (otherwise the browser blocks it with a `frame-ancestors` CSP error).
   The Terraform AWS provider has no resource for this yet, so do it via CLI:
   ```bash
   aws connect associate-approved-origin \
     --instance-id "$(terraform output -raw connect_instance_id)" \
     --origin "http://localhost:8080" \
     --region "$(terraform output -raw connect_instance_arn | cut -d: -f4)"
   ```
   (swap the origin for wherever you actually serve `app/web/`). Note this
   is per-instance state — reclaiming/recreating the instance (e.g. moving
   regions) resets the approved-origins list to empty.
3. Serve the app locally and open it — **do not** open `index.html` via
   `file://`; the browser sends `Origin: null` and Connect will reject it:
   ```bash
   cd app/web && python3 -m http.server 8080
   # then open http://localhost:8080
   ```
4. Enter your instance alias, click "Load Contact Control Panel", and log
   in with the `connect-admin` user.

## End-to-end test (voice call)

1. Claim a phone number: set `claim_phone_number = true` in
   `terraform.tfvars` (see also `phone_number_country_code` /
   `phone_number_type`) and `terraform apply`.
2. In the admin console (`terraform output -raw connect_instance_access_url`)
   go to **Channels → Phone numbers**, click the claimed number, set its
   contact flow to `SampleInboundFlow`, and save (no Terraform resource
   exists yet for this association).
3. Open the sample web app (see above), log in as `connect-admin`, and set
   agent status to **Available**.
4. Call the claimed number from any phone. You should hear the greeting,
   the Lambda lookup should run, and the call should ring your softphone
   in the CCP with customer attributes shown in the "Customer Info" panel.
5. Confirm the Lambda executed:
   ```bash
   aws logs tail /aws/lambda/<instance_alias>-customer-lookup --since 10m --region <aws_region>
   ```

## Usage

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # edit admin_password, region, alias
terraform init
terraform plan
terraform apply
```

## Requirements

- Terraform >= 1.5, AWS provider ~> 5.0
- An AWS account with Amazon Connect available in the chosen region
- Sufficient IAM permissions to create Connect, Lambda, IAM, and S3
  resources

## Notes / gotchas

- `instance_alias` must be globally unique across AWS.
- The default `HoursOfOperation` named "Basic Hours" is auto-created by
  Connect for every new instance; the queue references it via a data
  source rather than creating a duplicate.
- Destroying the instance (`terraform destroy`) also removes the queue,
  routing profile, user, contact flow, and Lambda association. The S3
  bucket is created with `force_destroy = true` for easy teardown in a
  demo — remove that for production use.
- **Admin console login URL**: newer Connect instances use
  `https://<instance_alias>.my.connect.aws/home`, not the older
  `https://<instance_id>.awsapps.com/connect/login` format. The CCP
  embed URL is `https://<instance_alias>.my.connect.aws/ccp-v2`. Both
  Terraform outputs (`connect_instance_access_url`, `connect_ccp_url`) and
  `app/web/app.js` use the `my.connect.aws` domain.
- **Contact flow JSON — `TransferContactToQueue` takes *no* parameters.**
  The destination queue must be set beforehand with a preceding
  `UpdateContactTargetQueue` action (`Parameters.QueueId`). Passing
  `QueueId` directly to `TransferContactToQueue` fails contact flow
  creation with `InvalidContactFlowException` (empty message — use
  `aws connect create-contact-flow ... --cli-error-format json` to see the
  actual `problems[].message` if you hit this again).
- **Admin user needs the built-in "Admin" security profile**, not just a
  custom one, or the console UI will appear mostly empty (no Channels,
  Flows, Users menus). Fetch it via `data "aws_connect_security_profile"
  { name = "Admin" }` and use its `.security_profile_id` (not `.id`, which
  is a compound `instance_id:profile_id` string the API rejects) in
  `aws_connect_user.security_profile_ids`.
- **Changing `aws_region` does not migrate resources.** Amazon Connect
  resources (and the S3 bucket) are region-scoped; Terraform state still
  points at the old region's resource IDs. To move regions:
  1. `terraform destroy -var="aws_region=<old_region>"` to tear down the
     old stack (this also releases any claimed phone number).
  2. Update `aws_region` in `terraform.tfvars`.
  3. `terraform apply` to build fresh in the new region.
- **S3 bucket name collisions after destroy/recreate**: recreating a
  bucket with the same name shortly after deleting it can hit
  `OperationAborted: A conflicting conditional operation is currently in
  progress against this resource` — S3 needs a little time to release the
  name. The bucket name includes `var.aws_region` specifically to avoid
  this when migrating regions with the same `instance_alias`.
- **Run `terraform apply`/`destroy` without piping through `tail`/`head`**
  when you need to watch progress live — piping buffers output until the
  process exits, making a slow-but-healthy apply look hung. If you do need
  to check on a long-running apply, use `nohup terraform apply -auto-approve
  > /tmp/tf.log 2>&1 &` and `tail -f`/re-read the log file.
- Claimable phone number type/country availability varies by region and
  AWS's inventory at claim time (e.g. `phone_number_country_code = "AU"`
  with a Sydney (`ap-southeast-2`) instance yields an AU DID; US inventory
  may also be offered depending on availability).
