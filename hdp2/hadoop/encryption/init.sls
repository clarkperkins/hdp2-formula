/root/server.crt:
  file:
    - managed
    - user: root
    - group: root
    - mode: 664
    - contents_pillar: hdp2:encryption:certificate

/root/server.key:
  file:
    - managed
    - user: root
    - group: root
    - mode: 664
    - contents_pillar: hdp2:encryption:private_key

convert-to-jks:
  cmd:
    - run
    - user: root
    - name: echo 'hadoop' | openssl pkcs12 -export -name {{ grains.id }} -in /root/server.crt -inkey /root/server.key -out /etc/hadoop/conf/hadoop.pkcs12 -password stdin
    - require:
      - file: /root/server.crt
      - file: /root/server.key

create-keystore:
  cmd:
    - run
    - user: root
    - name: '$JAVA_HOME/bin/keytool -importkeystore -srckeystore /etc/hadoop/conf/hadoop.pkcs12 -destkeystore /etc/hadoop/conf/hadoop.keystore -srcstoretype pkcs12 -srcalias {{ grains.id }} -destalias {{ grains.id }} -srcstorepass hadoop -deststorepass hadoop -destkeypass hadoop -noprompt'
    - require:
      - cmd: convert-to-jks

chown-keystore:
  cmd:
    - run
    - user: root
    - name: 'chown root:hadoop /etc/hadoop/conf/hadoop.keystore && chmod 440 /etc/hadoop/conf/hadoop.keystore'
    - require:
      - cmd: create-keystore

nginx:
  pkg:
    - installed

/etc/nginx/conf.d:
  file:
    - directory
    - clean: true
    - require:
      - pkg: nginx

/etc/nginx/conf.d/hadoop.conf:
  file:
    - managed
    - user: root
    - group: root
    - mode: 644
    - source: salt://hdp2/hadoop/encryption/hadoop.conf
    - template: jinja
    - require:
      - file: /etc/nginx/conf.d

nginx-svc:
  service:
    - running
    - name: nginx
    - watch:
      - file: /etc/nginx/conf.d
      - file: /etc/nginx/conf.d/hadoop.conf
