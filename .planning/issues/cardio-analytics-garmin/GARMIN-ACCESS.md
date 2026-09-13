# Requesting Garmin access for JackedLog

Checked against Garmin's official pages on 2026-09-13.

Garmin's public [program overview](https://developer.garmin.com/gc-developer-program/overview/)
currently says “Stay tuned for more updates on the program” and does not expose
an application link. The [official FAQ](https://developer.garmin.com/gc-developer-program/program-faq/)
lists connect-support@developer.garmin.com as the contact for questions.

## What to do

1. Email that address to ask whether new applications are open and whether
   JackedLog is eligible. Describe its actual status; do not invent a company,
   commercial deployment, or user count. Garmin states the program is for
   business/enterprise use, so a personal or open-source project needs an explicit
   eligibility answer.
2. Request Activity API access for completed activities and Health API access
   for daily HR, sleep, stress and any available Body Battery data. Ask which
   metrics need additional entitlement or licensing.
3. Include the public project URL, a short product description, intended users,
   Android platform, consent/disconnect/deletion behavior and hosting approach.
   Explain that the application has an optional AI coach, while Garmin health
   data is excluded from its prompts in the proposed integration. Ask Garmin to
   confirm applicable restrictions. Send no user records or credentials.
4. If accepted, follow Garmin's portal onboarding. Obtain the approved OAuth,
   notification verification, revision/deletion and backfill documentation,
   approved test credentials, anonymized fixtures and HTTPS callback setup.
   The public [developer portal overview](https://developerportal.garmin.com/developer-programs/connect-developer-api)
   links app/key creation and API documentation; it is not evidence that an
   unapproved account has access.

The FAQ describes a two-business-day application-status response and no general
access/maintenance fees, with possible charges for particular metrics. These are
not a promise that applications are currently open or that this project qualifies.
Connect IQ is a separate program and does not grant these cloud APIs.

## Suggested inquiry

Subject: JackedLog — Garmin Connect Developer Program eligibility and access

Hello Garmin Developer Support,

I maintain JackedLog, an Android workout tracker:
https://github.com/Aquatictw/JackedLog

I would like to ask whether you are accepting new Garmin Connect Developer
Program applications, and whether my project is eligible. I can provide its
current usage and business status for your review.

The planned integration imports user-authorized completed runs through the
Activity API and displays daily heart rate, sleep, stress and available Body
Battery through the Health API. Users would be able to disconnect and choose
whether to retain or delete imported data. Provider credentials would remain
on the server. The app includes an optional AI coach; the proposed integration
keeps Garmin health data out of coach prompts.

Could you advise on the current application process, eligibility requirements,
available metric entitlements and any applicable licensing or AI restrictions?
My initial test device is a Forerunner 265.

Thank you.

## Current implementation gates

The user has a Forerunner 265; firmware is not yet recorded. No Garmin Developer
Program access has been granted. Cloud connection/import/health tickets remain
gated on approval and contracts. Live HR requires validation on the physical
watch and phone; an Android emulator does not establish Bluetooth support.
