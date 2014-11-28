FROM node:0.8.28

ENV APP_HOME /usr/src/cloudsdale-push
ENV DEBIAN_FRONTEND noninteractive

# Create application home and make sure the current repository is added
RUN mkdir -p $APP_HOME
ADD . $APP_HOME
WORKDIR $APP_HOME

# Create an entrypoint for docker
COPY ./entrypoint.sh /
RUN chmod 0755 /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 8282:8282
CMD ["npm", "start"]