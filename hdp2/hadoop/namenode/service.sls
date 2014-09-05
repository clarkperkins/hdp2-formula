{%- set standby = salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:hdp2.hadoop.standby', 'grains.items', 'compound') -%}
{% set dfs_name_dir = salt['pillar.get']('hdp2:dfs:name_dir', '/mnt/hadoop/hdfs/nn') %}
{% set mapred_local_dir = salt['pillar.get']('hdp2:mapred:local_dir', '/mnt/hadoop/mapred/local') %}
{% set mapred_system_dir = salt['pillar.get']('hdp2:mapred:system_dir', '/hadoop/system/mapred') %}
{% set mapred_staging_dir = '/user/history' %}
{% set mapred_log_dir = '/var/log/hadoop-yarn' %}

##
# Standby NN specific SLS
##
{% if 'hdp2.hadoop.standby' in grains.roles %}
include:
  - hdp2.hadoop.standby.service
##
# END STANDBY NN
##

##
# Regular NN SLS
##
{% else %}

{% if grains['os_family'] == 'Debian' %}
extend:
  remove_policy_file:
    file:
      - require:
        - service: hadoop-hdfs-namenode-svc
        - service: hadoop-yarn-resourcemanager-svc
        - service: hadoop-mapreduce-historyserver-svc
{% endif %}

##
# Starts the namenode service.
#
# Depends on: JDK7
##
hadoop-hdfs-namenode-svc:
  service:
    - running
    - name: hadoop-hdfs-namenode
    - require: 
      - pkg: hadoop-hdfs-namenode
      # Make sure HDFS is initialized before the namenode
      # is started
      - cmd: init_hdfs
      - file: bigtop_java_home
    - watch:
      - file: /etc/hadoop/conf

{% if standby %}
##
# Sets this namenode as the "Active" namenode
##
activate_namenode:
  cmd:
    - run
    - name: 'hdfs haadmin -transitionToActive nn1'
    - user: hdfs
    - group: hdfs
    - require:
      - service: hadoop-hdfs-namenode-svc
      {% if salt['pillar.get']('hdp2:security:enable', False) %}
      - cmd: hdfs_kinit
      {% endif %}
{% endif %}

##
# Starts yarn resourcemanager service.
#
# Depends on: JDK7
##
hadoop-yarn-resourcemanager-svc:
  service:
    - running
    - name: hadoop-yarn-resourcemanager
    - require: 
      - pkg: hadoop-yarn-resourcemanager
      - service: hadoop-hdfs-namenode-svc
      - cmd: hdfs_mapreduce_var_dir
      - cmd: hdfs_mapreduce_log_dir
      - file: bigtop_java_home
    - watch:
      - file: /etc/hadoop/conf

##
# Installs the mapreduce historyserver service and starts it.
#
# Depends on: JDK7
##
hadoop-mapreduce-historyserver-svc:
  service:
    - running
    - name: hadoop-mapreduce-historyserver
    - require:
      - pkg: hadoop-mapreduce-historyserver
      - service: hadoop-hdfs-namenode-svc
      - file: bigtop_java_home
    - watch:
      - file: /etc/hadoop/conf

##
# Make sure the namenode metadata directory exists
# and is owned by the hdfs user
##
hdp2_dfs_dirs:
  cmd:
    - run
    - name: 'mkdir -p {{ dfs_name_dir }} && chown -R hdfs:hdfs `dirname {{ dfs_name_dir }}`'
    - unless: 'test -d {{ dfs_name_dir }}'
    - require:
      - pkg: hadoop-hdfs-namenode
      - file: bigtop_java_home
{% if salt['pillar.get']('hdp2:security:enable', False) %}
      - cmd: generate_hadoop_keytabs
{% endif %}

# Initialize HDFS. This should only run once, immediately
# following an install of hadoop.
init_hdfs:
  cmd:
    - run
    - user: hdfs
    - group: hdfs
    - name: 'hdfs namenode -format -force'
    - unless: 'test -d {{ dfs_name_dir }}/current'
    - require:
      - cmd: hdp2_dfs_dirs

# When security is enabled, we need to get a kerberos ticket
# for the hdfs principal so that any interaction with HDFS
# through the hadoop client may authorize successfully.
# NOTE this means that any 'hadoop fs' commands will need
# to require this state to be sure we have a krb ticket
{% if salt['pillar.get']('hdp2:security:enable', False) %}
hdfs_kinit:
  cmd:
    - run
    - name: 'kinit -kt /etc/hadoop/conf/hdfs.keytab hdfs/{{ grains.fqdn }}'
    - user: hdfs
    - group: hdfs
    - require:
      - service: hadoop-hdfs-namenode-svc
      - cmd: generate_hadoop_keytabs
{% endif %}

# HDFS tmp directory
hdfs_tmp_dir:
  cmd:
    - run
    - user: hdfs
    - group: hdfs
    - name: 'hadoop fs -mkdir /tmp && hadoop fs -chmod -R 1777 /tmp'
    - unless: 'hadoop fs -test -d /tmp'
    - require:
      - service: hadoop-hdfs-namenode-svc
      {% if salt['pillar.get']('hdp2:security:enable', False) %}
      - cmd: hdfs_kinit
      {% endif %}
      {% if standby %}
      - cmd: activate_namenode 
      {% endif %}

# HDFS MapReduce log directories
hdfs_mapreduce_log_dir:
  cmd:
    - run
    - user: hdfs
    - group: hdfs
    - name: 'hadoop fs -mkdir -p {{ mapred_log_dir }} && hadoop fs -chmod 1777 {{ mapred_log_dir }} && hadoop fs -chown -R yarn `dirname {{ mapred_log_dir }}`'
    - unless: 'hadoop fs -test -d {{ mapred_log_dir }}'
    - require:
      - service: hadoop-hdfs-namenode-svc
      {% if salt['pillar.get']('hdp2:security:enable', False) %}
      - cmd: hdfs_kinit
      {% endif %}
      {% if standby %}
      - cmd: activate_namenode 
      {% endif %}

# HDFS MapReduce var directories
hdfs_mapreduce_var_dir:
  cmd:
    - run
    - user: hdfs
    - group: hdfs
    - name: 'hadoop fs -mkdir -p {{ mapred_staging_dir }} && hadoop fs -chmod 1777 {{ mapred_staging_dir }} && hadoop fs -chown -R yarn `dirname {{ mapred_staging_dir }}`'
    - unless: 'hadoop fs -test -d {{ mapred_staging_dir }}'
    - require:
      - service: hadoop-hdfs-namenode-svc
      {% if salt['pillar.get']('hdp2:security:enable', False) %}
      - cmd: hdfs_kinit
      {% endif %}
      {% if standby %}
      - cmd: activate_namenode 
      {% endif %}

# set permissions at the root level of HDFS so any user can write to it
hdfs_permissions:
  cmd:
    - run
    - user: hdfs
    - group: hdfs
    - name: 'hadoop fs -chmod 777 /'
    - require:
      - service: hadoop-yarn-resourcemanager-svc
      {% if salt['pillar.get']('hdp2:security:enable', False) %}
      - cmd: hdfs_kinit
      {% endif %}
      {% if standby %}
      - cmd: activate_namenode 
      {% endif %}

# create a user directory owned by the stack user
{% set user = pillar.__stackdio__.username %}
hdfs_user_dir:
  cmd:
    - run
    - user: hdfs
    - group: hdfs
    - name: 'hdfs dfs -mkdir /user/{{ user }} && hdfs dfs -chown {{ user }}:{{ user }} /user/{{ user }}'
    - unless: 'hadoop fs -test -d /user/{{ user }}'
    - require:
      - service: hadoop-yarn-resourcemanager-svc
      {% if salt['pillar.get']('hdp2:security:enable', False) %}
      - cmd: hdfs_kinit
      {% endif %}
      {% if standby %}
      - cmd: activate_namenode 
      {% endif %}


#
##
# END REGULAR NAMENODE 
##
{% endif %}
