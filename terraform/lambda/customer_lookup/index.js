/**
 * Sample Lambda function invoked from an Amazon Connect contact flow.
 * Looks up a "customer" by the caller's phone number (ANI) and returns
 * attributes that the contact flow can use to personalize the call
 * (e.g. greet the caller by name, route VIPs to a priority queue).
 *
 * In this sample the "lookup" is mocked in-memory. Replace with a call
 * to DynamoDB, an internal CRM API, etc. for a real deployment.
 */
exports.handler = async (event) => {
  console.log("Connect event:", JSON.stringify(event));

  const callerNumber =
    event?.Details?.ContactData?.CustomerEndpoint?.Address || "unknown";

  const mockCustomers = {
    "+15551234567": { name: "Jane Doe", tier: "VIP" },
    "+15559876543": { name: "John Smith", tier: "Standard" },
    "+61416790792": { name: "Jack Dorsey", tier: "Standard" },
  };

  const customer = mockCustomers[callerNumber] || {
    name: "Guest",
    tier: "Standard",
  };

  return {
    customerName: customer.name,
    customerTier: customer.tier,
    isVip: customer.tier === "VIP" ? "true" : "false",
  };
};
