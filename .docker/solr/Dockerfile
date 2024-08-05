FROM solr:9.6.1
COPY ./solr/configs/ /opt/solr/configs

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["solr-foreground"]
