/etc/hbase/conf/hbase-site.xml:
  file.managed:
    - source: salt://hdp2/etc/hbase/conf/hbase-site.xml
    - user: root
    - group: root
    - mode: 644
    - template: jinja

/etc/hbase/conf/hbase-env.sh:
  file.managed:
    - source: salt://hdp2/etc/hbase/conf/hbase-env.sh
    - user: root
    - group: root
    - mode: 644
    - template: jinja

{{ pillar.hdp2.hbase.tmp_dir }}:
  file.directory:
    - user: hbase
    - group: hbase
    - dir_mode: 1777
    - makedirs: True

{{ pillar.hdp2.hbase.log_dir }}:
  file.directory:
    - user: hbase
    - group: hbase
    - dir_mode: 755
    - makedirs: True

/etc/hbase/conf/log4j.properties:
  file.replace:
    - pattern: 'maxbackupindex=20'
    - repl: 'maxbackupindex={{ pillar.hdp2.max_log_index }}'
    - require:
      - file: /etc/hbase/conf/hbase-site.xml
      - file: /etc/hbase/conf/hbase-env.sh
      - file: {{ pillar.hdp2.hbase.tmp_dir }}
      - file: {{ pillar.hdp2.hbase.log_dir }}

{% if pillar.hdp2.security.enable %}
/etc/hbase/conf/zk-jaas.conf:
  file.managed:
    - source: salt://hdp2/etc/hbase/conf/zk-jaas.conf
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - require:
      - file: /etc/hbase/conf/hbase-site.xml
      - file: /etc/hbase/conf/hbase-env.sh
{% endif %}
