Subject: SSH to login.hoffman2.oarc.ucla.edu denied by pam_slurm_adopt ("no active jobs on this node")

Ticket body:

Hello,

Since [DATE], SSH logins to the new OARC Hoffman2 cluster
(login.hoffman2.OARC.ucla.edu) are refused after successful public-key
authentication with the message:

    Access denied by pam_slurm_adopt: you have no active jobs on this node
    Connection closed by 192.154.2.205 (also observed on .206, .207, .208)

Details:

- This happens on all four login nodes (I probed each IP that
  login.hoffman2.oarc.ucla.edu resolves to).
- Public-key authentication itself succeeds; the connection is closed at
  the PAM account stage, so the failure is pam_slurm_adopt denying users
  with no active jobs.
- I hold no running jobs, so I cannot start one through the scheduler,
  and I cannot inspect my files or submit jobs at all.
- Before [DATE] I logged into the new cluster normally with the same key.
- The legacy cluster (hoffman2.idre.ucla.edu) still authenticates fine
  with the same key, so the key and account are not the issue.

Questions:

1. Is denying logins without active jobs (pam_slurm_adopt
   action_no_jobs=deny) now the intended policy on the OARC login nodes?
   If so, what is the supported way to submit a first job?
2. Or is this a migration-phase misconfiguration? My PI association
   (pi_olizardo) may have migrated during the mid-November node move.

My username is olizardo. Could you restore normal login access or advise
on the intended workflow?

Thank you,
Omar Lizardo
