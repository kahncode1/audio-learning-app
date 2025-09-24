/// Amplify Configuration for AWS Cognito Authentication
///
/// This configuration file sets up AWS Cognito for OAuth authentication
/// using the hosted UI with PKCE flow for mobile applications.
///
/// Test Environment Configuration:
/// - App Client ID: 7n2o5r6em0latepiui4rfg6vmi
/// - Hosted UI Domain: users.login-test.theinstitutes.org
/// - OAuth Redirect URIs: audiocourses://oauth/callback and audiocourses://oauth/logout

const amplifyconfig = '''{
  "UserAgent": "aws-amplify-cli/2.0",
  "Version": "1.0",
  "auth": {
    "plugins": {
      "awsCognitoAuthPlugin": {
        "UserAgent": "aws-amplify-cli/0.1.0",
        "Version": "0.1.0",
        "IdentityManager": {
          "Default": {}
        },
        "CognitoUserPool": {
          "Default": {
            "PoolId": "us-east-1_vAMMFcpew",
            "AppClientId": "7n2o5r6em0latepiui4rfg6vmi",
            "Region": "us-east-1"
          }
        },
        "Auth": {
          "Default": {
            "OAuth": {
              "WebDomain": "users.login-test.theinstitutes.org",
              "AppClientId": "7n2o5r6em0latepiui4rfg6vmi",
              "SignInRedirectURI": "audiocourses://oauth/callback",
              "SignOutRedirectURI": "audiocourses://oauth/logout",
              "Scopes": [
                "openid",
                "email",
                "profile"
              ],
              "ResponseType": "code"
            },
            "authenticationFlowType": "CUSTOM_AUTH",
            "socialProviders": [],
            "usernameAttributes": [
              "EMAIL"
            ],
            "signupAttributes": [
              "EMAIL"
            ],
            "passwordProtectionSettings": {
              "passwordPolicyMinLength": 8,
              "passwordPolicyCharacters": []
            },
            "mfaConfiguration": "OFF",
            "mfaTypes": [],
            "verificationMechanisms": [
              "EMAIL"
            ]
          }
        }
      }
    }
  }
}''';
