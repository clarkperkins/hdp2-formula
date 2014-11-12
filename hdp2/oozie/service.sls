{% set oozie_data_dir = '/var/lib/oozie' %}
{% set nn_host = salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:hdp2.hadoop.namenode and not G@roles:hdp2.hadoop.standby', 'grains.items', 'compound').values()[0]['fqdn_ip4'][0] %}
# 
# Start the Oozie service
#
{% if grains['os_family'] == 'Debian' %}
extend:
  remove_policy_file:
    file:
      - require:
        - service: oozie-svc
{% endif %}

oozie-svc:
  service:
    - running
    - name: oozie
    - require:
      - pkg: oozie
      - cmd: extjs
      - cmd: ooziedb
      - cmd: populate-oozie-sharelibs
      - file: /var/log/oozie
      - file: /var/lib/oozie

prepare_server:
  cmd:
    - run
    - name: '/usr/lib/oozie/bin/oozie-setup.sh prepare-war'
    - unless: 'service oozie status'
    - user: root
    - require:
      - pkg: oozie
      - cmd: extjs
{% if salt['pillar.get']('hdp2:security:enable', False) %}
      - file: /etc/oozie/conf/oozie-site.xml
      - cmd: generate_oozie_keytabs
{% endif %}


ooziedb:
  cmd:
    - run
    - name: '/usr/lib/oozie/bin/ooziedb.sh create -sqlfile oozie.sql -run Validate DB Connection'
    - unless: 'test -d {{ oozie_data_dir }}/oozie-db'
    - user: oozie
    - require:
      - cmd: prepare_server


create-oozie-sharelibs:
  cmd:
    - run
    - name: 'hdfs dfs -mkdir /user/oozie && hdfs dfs -chown -R oozie:oozie /user/oozie && hdfs dfs -chmod 777 /user'
    - unless: 'hdfs dfs -test -d /user/oozie'
    - user: hdfs
    - require:
      - cmd: ooziedb

populate-oozie-sharelibs:
  cmd:
    - run
    - name: '/usr/lib/oozie/bin/oozie-setup.sh sharelib create -fs hdfs://{{nn_host}}:8020 -locallib /usr/lib/oozie/oozie-sharelib.tar.gz'
    - unless: 'hdfs dfs -test -d /user/oozie/share'
    - user: oozie 
    - require:
      - cmd: create-oozie-sharelibs

