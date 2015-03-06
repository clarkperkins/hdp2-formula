
# 
# Start the Hive service
#

include:
  - hdp2.repo


# @todo move this out to its own formula
mysql-svc:
  service:
    - running
    {% if grains['os_family'] == 'Debian' %}
    - name: mysql
    {% elif grains['os_family'] == 'RedHat' %}
    - name: mysqld
    {% endif %}
    - require:
      - pkg: mysql

configure_metastore:
  cmd:
    - script
    - template: jinja
    - source: salt://hdp2/hive/configure_metastore.sh
    - unless: echo "show databases" | mysql -u root | grep metastore
    - require:
      - pkg: hive
      - service: mysql-svc

create_warehouse_dir:
  cmd:
    - run
    - name: 'hdfs dfs -mkdir -p /user/{{pillar.hdp2.hive.user}}/warehouse'
    - user: hdfs
    - group: hdfs
    - require:
      - pkg: hive
{% if salt['pillar.get']('hdp2:security:enable', False) %}
      - cmd: generate_hive_keytabs 
{% endif %}

warehouse_dir_owner:
  cmd:
    - run
    - name: 'hdfs dfs -chown -R {{pillar.hdp2.hive.user}}:{{pillar.hdp2.hive.user}} /user/{{pillar.hdp2.hive.user}}'
    - user: hdfs
    - group: hdfs
    - require:
      - cmd: create_warehouse_dir

warehouse_dir_permissions:
  cmd:
    - run
    {% if salt['pillar.get']('hdp2:security:enable', False) %}
    - name: 'hdfs dfs -chmod 771 /user/{{pillar.hdp2.hive.user}}/warehouse'
    {% else %}
    - name: 'hdfs dfs -chmod 1777 /user/{{pillar.hdp2.hive.user}}/warehouse'
    {% endif %}
    - user: hdfs
    - group: hdfs
    - require:
      - cmd: warehouse_dir_owner

hive-metastore:
  service:
    - running
    - require:
      - pkg: hive
      - cmd: configure_metastore
      - cmd: warehouse_dir_permissions
      - service: mysql-svc
      - file: /usr/lib/hive/lib/mysql-connector-java.jar
      - file: /etc/hive/conf/hive-site.xml
      - file: /mnt/tmp/
    - watch:
      - file: /etc/hive/conf/hive-site.xml

hive-server2:
  service:
    - running
    - require: 
      - service: hive-metastore
{% if salt['pillar.get']('hdp2:security:enable', False) %}
      - cmd: generate_hive_keytabs 
{% endif %}
    - watch:
      - file: /etc/hive/conf/hive-site.xml

/mnt/tmp/:
  file:
    - directory
    - user: root
    - group: root
    - dir_mode: 777
    - recurse:
      - mode
