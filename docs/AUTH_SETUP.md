# Auth Setup

## Implemented

The API uses its own email/password endpoints because this Flutter client expects a Bearer `session_token`. Passwords are bcrypt hashes; bearer tokens are random and only their SHA-256 hashes are stored in `app_sessions`. Each private API request validates the session and takes the data owner ID from that session, not from the request body.

Sign-up, sign-in, current-profile read/update, and sign-out are implemented. Flutter stores the session token with Flutter Secure Storage.

## Not configured

Email verification and forgot-password email delivery need a real email provider. The reset endpoint returns an explicit unavailable response until that is set up. Add request rate limiting and email verification before a public production deployment. This custom API session is not Neon Auth and must not be presented as Neon Auth.

Database passwords belong only in the backend runtime secret store. Rotate the connection password shared in chat before continued use.
