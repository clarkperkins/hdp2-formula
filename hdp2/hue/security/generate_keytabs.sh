{%- from 'krb5/settings.sls' import krb5 with context %}
{%- set realm = krb5.realm -%}
#!/bin/bash
(
echo "addprinc -randkey hue/{{ grains.fqdn }}@{{ realm }}"
echo "xst -k hue.keytab hue/{{ grains.fqdn }}@{{ realm }}"
) | kadmin -p kadmin/admin -kt /root/admin.keytab

chown hue:hue hue.keytab
chmod 400 *.keytab
