/**
 * Sample agent app built on Amazon Connect Streams.
 * Embeds the Contact Control Panel (CCP) and surfaces the customer
 * attributes returned by the "customer_lookup" Lambda function that the
 * Terraform-provisioned contact flow invokes.
 *
 * Docs: https://github.com/amazon-connect/amazon-connect-streams
 */
document.getElementById("init-btn").addEventListener("click", () => {
  const alias = document.getElementById("instance-alias").value.trim();
  if (!alias) {
    alert("Enter your Connect instance alias first.");
    return;
  }

  const ccpUrl = `https://${alias}.my.connect.aws/ccp-v2`;
  const container = document.getElementById("ccp");
  container.innerHTML = "";

  connect.core.initCCP(container, {
    ccpUrl,
    loginPopup: true,
    loginPopupAutoClose: true,
    softphone: {
      allowFramedSoftphone: true,
    },
  });

  connect.contact((contact) => {
    contact.onConnecting(() => {
      const attributes = contact.getAttributes();
      const pretty = Object.fromEntries(
        Object.entries(attributes).map(([k, v]) => [k, v.value])
      );
      document.getElementById("customer-attrs").textContent = JSON.stringify(
        pretty,
        null,
        2
      );
    });

    contact.onEnded(() => {
      document.getElementById("customer-attrs").textContent =
        "No active contact.";
    });
  });
});
