FROM gitea/gitea:1.21

USER root

RUN apk add --no-cache postgresql-client su-exec curl

COPY startup.sh /usr/local/bin/startup.sh
RUN chmod +x /usr/local/bin/startup.sh

EXPOSE 3000

ENTRYPOINT ["/usr/local/bin/startup.sh"]
