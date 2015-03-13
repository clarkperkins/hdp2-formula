{%- from 'krb5/settings.sls' import krb5 with context %}
{%- set realm = krb5.realm -%}
#!/bin/bash
(
echo "addprinc -randkey zookeeper/{{ grains.fqdn }}@{{ realm }}"
echo "xst -k zookeeper.keytab zookeeper/{{ grains.fqdn }}@{{ realm }}"
) | kadmin -p kadmin/admin -kt /root/admin.keytab

chown zookeeper:hadoop zookeeper.keytab
chmod 400 *.keytab
