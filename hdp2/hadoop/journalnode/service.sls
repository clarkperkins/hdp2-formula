{% set journal_dir = salt['pillar.get']('hdp2:dfs:journal_dir', '/mnt/hadoop/hdfs/jn') %}

##
# Starts the journalnode service.
#
# Depends on: JDK7
##
hadoop-hdfs-journalnode-svc:
  cmd:
    - run
    - user: hdfs
    - name: /usr/hdp/current/hadoop-hdfs-journalnode/../hadoop/sbin/hadoop-daemon.sh start namenode
    - unless: '. /etc/init.d/functions && pidofproc -p /var/run/hadoop/hdfs/hadoop-hdfs-journalnode.pid'
    - require:
      - pkg: hadoop-hdfs-journalnode
      - file: bigtop_java_home
      - cmd: hdp2_journal_dir
    - watch:
      - file: /etc/hadoop/conf

# Make sure the journal data directory exists if necessary
hdp2_journal_dir:
  cmd:
    - run
    - name: 'mkdir -p {{ journal_dir }} && chown -R hdfs:hdfs `dirname {{ journal_dir }}`'
    - unless: 'test -d {{ journal_dir }}'
    - require:
      - pkg: hadoop-hdfs-journalnode
      - file: bigtop_java_home
      {% if salt['pillar.get']('hdp2:security:enable', False) %}
      - cmd: generate_hadoop_keytabs
      {% endif %}
