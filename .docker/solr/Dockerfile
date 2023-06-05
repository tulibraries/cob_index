FROM solr:8.11.1
COPY ./solr/configs/ /opt/solr/configs

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["solr-foreground"]
