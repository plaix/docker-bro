FROM debian:jessie

MAINTAINER blacktop, https://github.com/blacktop

# Install Bro Required Dependencies
RUN buildDeps='libgoogle-perftools-dev \
	      ca-certificates \
              build-essential \
              libcurl4-gnutls-dev \
              libgeoip-dev \
              libpcap-dev \
              libssl-dev \
              python-dev \
              zlib1g-dev \
              ocl-icd-opencl-dev \		
              libboost-dev \		
	      doxygen \	
              git-core \
              cmake \
              make \
              g++ \
              gcc \
              wget \			
              python-software-properties \	
              python-dev' \
  && set -x \
  && echo "[INFO] Installing Dependancies..." \
  && apt-get -qq update \
  && apt-get install -yq $buildDeps \
                      php5-curl \
                      sendmail \
                      openssl \
                      bison \
                      flex \
                      gawk \
                      swig \
                      curl --no-install-recommends \
  # installing libcaf to enable broker , fix from danielguerra69
  && echo "[INFO] Installing libcaf Actor Framework..." \
  && cd /tmp \
  && git clone --recursive https://github.com/actor-framework/actor-framework.git \
  && cd actor-framework \
  # temp fix for buggy release 20/09/2015
  && git submodule foreach git checkout master \
  && git submodule foreach git pull \
  && ./configure --no-riac \
  && make \
  && make install \
  && rm -rf /tmp/actor-framework \

  && echo "[INFO] Installing Bro..." \
  && cd /tmp \
  && git clone --recursive git://git.bro.org/bro \
  && cd bro && ./configure --prefix=/nsm/bro \
  && make \
  && make install \
  && rm -rf /tmp/bro 

# Add Scripts Folder
ADD /scripts /scripts
ADD /scripts/local.bro /nsm/bro/share/bro/site/local.bro
# install the kibana init.d service script
ADD /scripts/kibana4 /etc/init.d/kibana4

# Install ELK stack
RUN \
  echo "[INFO] Installing ELK stack..." \
  && echo "[INFO] Installing ElasticSearch ..." \
  && apt-get install -yq software-properties-common \
  && wget -O - http://packages.elasticsearch.org/GPG-KEY-elasticsearch | apt-key add - \
  && echo 'deb http://packages.elasticsearch.org/elasticsearch/1.4/debian stable main' | tee /etc/apt/sources.list.d/elasticsearch.list \
  && echo 'deb http://packages.elasticsearch.org/logstash/1.5/debian stable main' | tee /etc/apt/sources.list.d/logstash.list \
  && apt-get update \
  && apt-get -y install openjdk-7-jdk elasticsearch=1.4.4 logstash 

RUN \
  echo "[INFO] Configuring Kibana ..." \
  && cd /tmp  \
  && wget https://download.elasticsearch.org/kibana/kibana/kibana-4.0.1-linux-x64.tar.gz \   
  && tar xvf kibana-*.tar.gz \
  && mkdir -p /opt/kibana \
  && cp -R /tmp/kibana-4*/* /opt/kibana/ \
  # script is included above in the Scripts Folder
  && chmod +x /etc/init.d/kibana4 \
  && update-rc.d kibana4 defaults 96 9 \
  && echo "[INFO] Configuring Logstash ..." \
  && cd /opt/logstash  \
  && ls -alh \
  && ./bin/plugin install logstash-filter-translate \
  # get the bro logstash files from timmolter github
  && cd /etc/logstash/conf.d/ \
  && wget -N https://raw.githubusercontent.com/timmolter/logstash-dfir/master/conf_files/bro/bro-conn_log.conf \
  && wget -N https://raw.githubusercontent.com/timmolter/logstash-dfir/master/conf_files/bro/bro-dns_log.conf \
  && wget -N https://raw.githubusercontent.com/timmolter/logstash-dfir/master/conf_files/bro/bro-files_log.conf \
  && wget -N https://raw.githubusercontent.com/timmolter/logstash-dfir/master/conf_files/bro/bro-http_log.conf \
  && wget -N https://raw.githubusercontent.com/timmolter/logstash-dfir/master/conf_files/bro/bro-notice_log.conf \
  && wget -N https://raw.githubusercontent.com/timmolter/logstash-dfir/master/conf_files/bro/bro-ssh_log.conf \
  && wget -N https://raw.githubusercontent.com/timmolter/logstash-dfir/master/conf_files/bro/bro-ssl_log.conf \
  && wget -N https://raw.githubusercontent.com/timmolter/logstash-dfir/master/conf_files/bro/bro-weird_log.conf \
  && wget -N https://raw.githubusercontent.com/timmolter/logstash-dfir/master/conf_files/bro/bro-x509_log.conf \
  # Fix the input folders
  # TODO : make workdir a variable
  && sed -i s#/nsm/bro/logs/current/#/pcap/# bro*log.conf


RUN \
  echo "[INFO] Cleaning image to reduce size..." \
  && apt-get remove -y $buildDeps \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


# Install the GeoIPLite Database
ADD /geoip /usr/share/GeoIP/
RUN \
  gunzip /usr/share/GeoIP/GeoLiteCityv6.dat.gz && \
  gunzip /usr/share/GeoIP/GeoLiteCity.dat.gz && \
  rm -f /usr/share/GeoIP/GeoLiteCityv6.dat.gz && \
  rm -f /usr/share/GeoIP/GeoLiteCity.dat.gz && \
  ln -s /usr/share/GeoIP/GeoLiteCityv6.dat /usr/share/GeoIP/GeoIPCityv6.dat && \
  ln -s /usr/share/GeoIP/GeoLiteCity.dat /usr/share/GeoIP/GeoIPCity.dat

ENV PATH /nsm/bro/bin:$PATH

# Add PCAP Test Folder
ADD /pcap/heartbleed.pcap /pcap/
VOLUME ["/pcap"]
WORKDIR /pcap

ADD /scripts/start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

EXPOSE 5601 9200 9300 5000

#ENTRYPOINT ["bro"]

CMD ["/usr/local/bin/start.sh"]
