FROM gitea/gitea:1.21

RUN apk add --no-cache postgresql-client su-exec curl

COPY startup.sh /app/startup.sh
RUN chmod +x /app/startup.sh

EXPOSE 3000

ENTRYPOINT ["/startup.sh"]