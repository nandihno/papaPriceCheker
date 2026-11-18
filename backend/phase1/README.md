# Phase one: Apple sign-in and favourites

**Status:** partially configured. On 2026-11-18 the account owner approved applying the favourites table and its policies to the live grocery project through the SQL editor. Apple sign-in was enabled with the native bundle ID and email-optional setting after the account owner approved the provider change. The deletion Edge Function was deployed on 2026-11-18 with JWT verification enabled. The SQL editor did not record migration version `20261118000001`; migration history requires reconciliation. The app's guest browsing remains available, but its sign-in, favourites and account deletion are not ready for production use until setup and end-to-end testing are complete.

The existing grocery backend is owned by `GroceryActor-apify/woolworths-actor`. The reviewed files now exist as uncommitted local changes in that backend repository; its migration and function deployment workflow owns them. Never deploy from this directory blindly or use a generic deploy command that changes unrelated functions or settings.

## Components

- `woolworths-actor/supabase/migrations/20261118000001_user_favourites.sql` creates a user/product join table, least-privilege grants and per-user RLS policies. The `auth.users` and `products` foreign keys cascade to the user's favourites. Existing public grocery tables and policies are not altered.
- `woolworths-actor/supabase/functions/delete-account/index.ts` requires a valid Supabase session and a fresh Apple identity token with a matching subject and nonce. It validates the token with Apple’s public keys, attempts to exchange the authorization code and revoke the Apple token, and deletes that same Supabase user. Its service-role key and Apple signing key stay on the server. If revocation fails, account deletion still proceeds and the app explains how to remove the Apple authorization manually. If deletion fails after revocation, the user must reauthorize and retry.
- The iOS app uses Supabase Swift 2.55.6 and the native Apple sign-in entitlement. Its public grocery client remains read-only and anonymous.

## External setup and release gates

1. Review the migration, function, data retention and account deletion behavior. Check the grocery backend repository’s existing migration history before deploying its new files. On 2026-11-18 the dashboard showed hosted versions `20261117002559` and `20261117013605`, while the corresponding local files use `20261117000001` and `20261117000002`. Do not run a generic database push until the migration history is reconciled and a dry run proves only the favourites migration will execute. The CLI dry run and direct connection to the configured database pooler timed out. After the SQL-editor rollout, version `20261118000001` is also missing from the hosted migration history even though its table exists. Do not replay it or perform a migration repair without independently comparing the live schema and local migrations, establishing a reviewed reconciliation plan, and regaining CLI connectivity.
2. Enable Sign in with Apple for the app's App ID in the Apple Developer account, ensure provisioning reflects the entitlement, and configure Supabase Auth's Apple provider with the native bundle ID `org.nando.Papa-PriceChecker`. The app does not request an email address, so enable the provider’s “Allow users without an email” setting and verify native sign-in. A Services ID and OAuth secret are for web OAuth, not required for this native-only flow. The account holder accepted the updated developer agreement, the signed device build succeeded, and the user reported successful Apple sign-in on an iPhone on 2026-11-18.
3. For the deletion function, arrange a Sign in with Apple server signing key in the Apple Developer account and configure the following **server-only** Edge Function secrets using the Supabase dashboard or an appropriately secured secrets workflow: `APPLE_TEAM_ID`, `APPLE_SIGN_IN_KEY_ID`, `APPLE_SIGN_IN_CLIENT_ID` (the native bundle ID), and `APPLE_SIGN_IN_PRIVATE_KEY` (the PKCS#8 `.p8` content). On 2026-11-18 the four Apple signing secrets were added to the live project with the account owner’s approval; their names were verified by a read-only check. End-to-end signing and revocation have not yet been tested. Do not commit the private key, print it, or paste it into chat. Supabase provides `SUPABASE_URL`, `SUPABASE_ANON_KEY` and `SUPABASE_SERVICE_ROLE_KEY` to the function environment.
4. Reconcile the migration history. The reviewed `delete-account` function is deployed with JWT verification enabled. The favourites table has already been applied through the SQL editor; do not run its CREATE TABLE migration again. The provider is enabled, and the function is configured; its unauthenticated denial was tested, but real account deletion remains untested. The user reported successful Apple sign-in on an iPhone. Do not modify the existing `ingest-apify-run` function or its `verify_jwt = false` setting. Inspect the plan/diff first; never run a remote reset.
5. Validate on a staging project and signed device: Apple sign-in and cancellation, session restore and revocation, save/remove/reload across two accounts and devices, cross-user RLS denial, sign-out, offline/error handling, and account deletion/revocation including failed Apple and Supabase requests. Confirm existing anonymous browsing and the ingest pipeline still work. Then repeat targeted checks against production as appropriate.

No changes in this proposal implement price notifications; those are phase two.

## Verification performed

- The favourites SQL succeeded in a transaction ending in `ROLLBACK` against the live database. After explicit approval, the same table, index and policies were applied with `COMMIT`. A subsequent read-only query confirmed the table exists, RLS is enabled, three policies exist, anonymous access is denied, and authenticated grants are correct. The query also confirmed migration history has not recorded the new version. Live cross-user behaviour has not been tested.

- After deployment, the `delete-account` function was active with JWT verification enabled and returned HTTP 401 to an unauthenticated request. The existing `ingest-apify-run` remained active with its prior JWT setting. This does not verify deletion or Apple revocation end to end.

### Isolated checks

- Migration and `woolworths-actor/supabase/tests/favourites_rls.sql` passed in a disposable `supabase/postgres:17.6.1.054` container with separate test users. Checks covered user isolation, anonymous denial, duplicate inserts, update denial and cascade deletion.
- `woolworths-actor/supabase/functions/delete-account/index_test.ts` passed in a Deno 2.5.6 container with mocked Supabase and Apple endpoints. It checks invalid sessions, missing identity tokens, mismatched Apple identities and nonces, failed revocation, successful deletion, and protection against revoking a different Apple account. These checks use test keys and do not replace real Apple integration or backend security review.
- The iOS app built for device and launched in an iPhone Duo simulator. The signed-out Favourites entry, product heart and sign-in prompts were visible. After enabling the provider, a fresh simulator build succeeded and Apple sign-in prompted for an Apple Account in simulator Settings. The user reported successful Apple sign-in on an iPhone on 2026-11-18. The user also confirmed adding a favourite and seeing it persist after closing and reopening the app on the iPhone. Cross-device syncing, cross-user isolation on the live project, and account deletion have not yet been confirmed end to end.

To run the isolated Edge Function checks from the grocery backend repository (Docker required):

```sh
docker run --rm \
  -v "$PWD/supabase/functions/delete-account:/work:ro" -w /work \
  denoland/deno:2.5.6 deno test --allow-env index_test.ts
```
