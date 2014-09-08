# 
# Start the Hue service
#
{% if grains['os_family'] == 'Debian' %}
extend:
  remove_policy_file:
    file:
      - require:
        - service: hue-svc
{% endif %}

hue-svc:
  service:
    - running
    - name: hue
    - require:
      - pkg: hue
      - file: /mnt/tmp/hadoop
      - file: /etc/hue/conf/hue.ini
{% if salt['pillar.get']('hdp2:security:enable', False) %}
      - cmd: generate_hue_keytabs 
{% endif %}

/etc/hue/conf/hue.ini:
  file:
    - managed
    - template: jinja
    - source: salt://hdp2/etc/hue/hue.ini
    - mode: 755
