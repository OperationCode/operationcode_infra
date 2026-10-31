# Import blocks for the operationcode.org zone and its pre-existing records.
# They can be removed after the first successful apply.

import {
  to = aws_route53_zone.operationcode
  id = "Z08173331NAK6ZJUBZENQ"
}

import {
  to = aws_route53_record.apex_a
  id = "Z08173331NAK6ZJUBZENQ_operationcode.org_A"
}

import {
  to = aws_route53_record.apex_caa
  id = "Z08173331NAK6ZJUBZENQ_operationcode.org_CAA"
}

import {
  to = aws_route53_record.apex_mx
  id = "Z08173331NAK6ZJUBZENQ_operationcode.org_MX"
}

import {
  to = aws_route53_record.apex_txt
  id = "Z08173331NAK6ZJUBZENQ_operationcode.org_TXT"
}

import {
  to = aws_route53_record.sendgrid_link_tracking
  id = "Z08173331NAK6ZJUBZENQ_5672389.operationcode.org_CNAME"
}

import {
  to = aws_route53_record.acm_validation_apex
  id = "Z08173331NAK6ZJUBZENQ__62bdef8daffb0b85a77bd7a7c4be6e36.operationcode.org_CNAME"
}

import {
  to = aws_route53_record.apex_dmarc
  id = "Z08173331NAK6ZJUBZENQ__dmarc.operationcode.org_TXT"
}

import {
  to = aws_route53_record.mailchimp_dkim_k2
  id = "Z08173331NAK6ZJUBZENQ_k2._domainkey.operationcode.org_CNAME"
}

import {
  to = aws_route53_record.mailchimp_dkim_k3
  id = "Z08173331NAK6ZJUBZENQ_k3._domainkey.operationcode.org_CNAME"
}

import {
  to = aws_route53_record.mandrill_dkim
  id = "Z08173331NAK6ZJUBZENQ_mandrill._domainkey.operationcode.org_TXT"
}

import {
  to = aws_route53_record.sendgrid_dkim_s1
  id = "Z08173331NAK6ZJUBZENQ_s1._domainkey.operationcode.org_CNAME"
}

import {
  to = aws_route53_record.sendgrid_dkim_s2
  id = "Z08173331NAK6ZJUBZENQ_s2._domainkey.operationcode.org_CNAME"
}

import {
  to = aws_route53_record.vercel_now_verification
  id = "Z08173331NAK6ZJUBZENQ__now.operationcode.org_TXT"
}

import {
  to = aws_route53_record.api_a
  id = "Z08173331NAK6ZJUBZENQ_api.operationcode.org_A"
}

import {
  to = aws_route53_record.api_aaaa
  id = "Z08173331NAK6ZJUBZENQ_api.operationcode.org_AAAA"
}

import {
  to = aws_route53_record.community_a
  id = "Z08173331NAK6ZJUBZENQ_community.operationcode.org_A"
}

import {
  to = aws_route53_record.kibana
  id = "Z08173331NAK6ZJUBZENQ_kibana.operationcode.org_CNAME"
}

import {
  to = aws_route53_record.mautic
  id = "Z08173331NAK6ZJUBZENQ_mautic.operationcode.org_CNAME"
}

import {
  to = aws_route53_record.sendgrid_notify_link
  id = "Z08173331NAK6ZJUBZENQ_link.notify.operationcode.org_CNAME"
}

import {
  to = aws_route53_record.sendgrid_notify_mail
  id = "Z08173331NAK6ZJUBZENQ_mail.notify.operationcode.org_CNAME"
}

import {
  to = aws_route53_record.sendgrid_notify_o1
  id = "Z08173331NAK6ZJUBZENQ_o1.notify.operationcode.org_A"
}

import {
  to = aws_route53_record.pybot_a
  id = "Z08173331NAK6ZJUBZENQ_pybot.operationcode.org_A"
}

import {
  to = aws_route53_record.pybot_aaaa
  id = "Z08173331NAK6ZJUBZENQ_pybot.operationcode.org_AAAA"
}

import {
  to = aws_route53_record.resources_a
  id = "Z08173331NAK6ZJUBZENQ_resources.operationcode.org_A"
}

import {
  to = aws_route53_record.resources_aaaa
  id = "Z08173331NAK6ZJUBZENQ_resources.operationcode.org_AAAA"
}

import {
  to = aws_route53_record.services_a
  id = "Z08173331NAK6ZJUBZENQ_services.operationcode.org_A"
}

import {
  to = aws_route53_record.services_nfs_a
  id = "Z08173331NAK6ZJUBZENQ_nfs.services.operationcode.org_A"
}

import {
  to = aws_route53_record.slash_commands
  id = "Z08173331NAK6ZJUBZENQ_slash-commands.operationcode.org_CNAME"
}

import {
  to = aws_route53_record.acm_validation_staging
  id = "Z08173331NAK6ZJUBZENQ__38e269ddbc8fefe222fbb84bdd604ea1.staging.operationcode.org_CNAME"
}

import {
  to = aws_route53_record.api_staging_a
  id = "Z08173331NAK6ZJUBZENQ_api.staging.operationcode.org_A"
}

import {
  to = aws_route53_record.api_staging_aaaa
  id = "Z08173331NAK6ZJUBZENQ_api.staging.operationcode.org_AAAA"
}

import {
  to = aws_route53_record.storybook
  id = "Z08173331NAK6ZJUBZENQ_storybook.operationcode.org_CNAME"
}

import {
  to = aws_route53_record.test
  id = "Z08173331NAK6ZJUBZENQ_test.operationcode.org_CNAME"
}

import {
  to = aws_route53_record.www_a
  id = "Z08173331NAK6ZJUBZENQ_www.operationcode.org_A"
}
