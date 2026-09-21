{
  "Version": "2019-10-30",
  "StartAction": "welcome-message",
  "Actions": [
    {
      "Identifier": "welcome-message",
      "Type": "MessageParticipant",
      "Parameters": {
        "Text": "Thank you for calling the Niroj Connect. Please wait while we look up your account."
      },
      "Transitions": {
        "NextAction": "invoke-customer-lookup",
        "Errors": [
          {
            "NextAction": "invoke-customer-lookup",
            "ErrorType": "NoMatchingError"
          }
        ]
      }
    },
    {
      "Identifier": "invoke-customer-lookup",
      "Type": "InvokeLambdaFunction",
      "Parameters": {
        "LambdaFunctionARN": "${lambda_arn}",
        "InvocationTimeLimitSeconds": "8",
        "ResponseValidation": {
          "ResponseType": "STRING_MAP"
        }
      },
      "Transitions": {
        "NextAction": "save-customer-attributes",
        "Errors": [
          {
            "NextAction": "play-error-message",
            "ErrorType": "NoMatchingError"
          }
        ]
      }
    },
    {
      "Identifier": "save-customer-attributes",
      "Type": "UpdateContactAttributes",
      "Parameters": {
        "TargetContact": "Current",
        "Attributes": {
          "customerName": "$.External.customerName",
          "customerTier": "$.External.customerTier",
          "isVip": "$.External.isVip"
        }
      },
      "Transitions": {
        "NextAction": "check-vip",
        "Errors": [
          {
            "NextAction": "check-vip",
            "ErrorType": "NoMatchingError"
          }
        ]
      }
    },
    {
      "Identifier": "check-vip",
      "Type": "Compare",
      "Parameters": {
        "ComparisonValue": "$.External.isVip"
      },
      "Transitions": {
        "NextAction": "play-standard-message",
        "Conditions": [
          {
            "NextAction": "play-vip-message",
            "Condition": {
              "Operator": "Equals",
              "Operands": ["true"]
            }
          }
        ],
        "Errors": [
          {
            "NextAction": "play-standard-message",
            "ErrorType": "NoMatchingCondition"
          }
        ]
      }
    },
    {
      "Identifier": "play-vip-message",
      "Type": "MessageParticipant",
      "Parameters": {
        "Text": "Welcome back, valued VIP customer. Connecting you to a priority agent."
      },
      "Transitions": {
        "NextAction": "set-working-queue",
        "Errors": [
          {
            "NextAction": "set-working-queue",
            "ErrorType": "NoMatchingError"
          }
        ]
      }
    },
    {
      "Identifier": "play-standard-message",
      "Type": "MessageParticipant",
      "Parameters": {
        "Text": "Thank you. Connecting you to the next available agent."
      },
      "Transitions": {
        "NextAction": "set-working-queue",
        "Errors": [
          {
            "NextAction": "set-working-queue",
            "ErrorType": "NoMatchingError"
          }
        ]
      }
    },
    {
      "Identifier": "play-error-message",
      "Type": "MessageParticipant",
      "Parameters": {
        "Text": "We were unable to look up your account, but we will still connect you to an agent."
      },
      "Transitions": {
        "NextAction": "set-working-queue",
        "Errors": [
          {
            "NextAction": "set-working-queue",
            "ErrorType": "NoMatchingError"
          }
        ]
      }
    },
    {
      "Identifier": "set-working-queue",
      "Type": "UpdateContactTargetQueue",
      "Parameters": {
        "QueueId": "${queue_arn}"
      },
      "Transitions": {
        "NextAction": "transfer-to-queue",
        "Errors": [
          {
            "NextAction": "transfer-to-queue",
            "ErrorType": "NoMatchingError"
          }
        ]
      }
    },
    {
      "Identifier": "transfer-to-queue",
      "Type": "TransferContactToQueue",
      "Parameters": {},
      "Transitions": {
        "NextAction": "disconnect",
        "Errors": [
          {
            "NextAction": "disconnect",
            "ErrorType": "NoMatchingError"
          },
          {
            "NextAction": "disconnect",
            "ErrorType": "QueueAtCapacity"
          }
        ]
      }
    },
    {
      "Identifier": "disconnect",
      "Type": "DisconnectParticipant",
      "Parameters": {}
    }
  ]
}
