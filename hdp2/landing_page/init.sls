{% if salt['pillar.get']('hdp2:landing_page', True) %}

{% set settings = salt['grains.filter_by']({
      'Debian': {
          'package_name': 'apache2',
          'html_file': '/var/www/index.html',
      },
      'RedHat': {
          'package_name': 'httpd',
          'html_file': '/var/www/html/index.html',
      },
}) %}


# Install thttpd or apache
webserver:
  pkg:
    - installed
    - name: {{ settings.package_name }}
  service:
    - running
    - name: {{ settings.package_name }}
    - require:
      - pkg: webserver
      - file: landing_html


# Setup the landing page
landing_html:
  file:
    - managed
    - name: {{ settings.html_file }}
    - source: salt://hdp2/landing_page/index.html
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - makedirs: true
    - require:
      - pkg: webserver

{% endif %}
