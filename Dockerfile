FROM postgres:alpine

# Set working directory
RUN mkdir /opt/pgsql-maintenance
WORKDIR /opt/pgsql-maintenance

# Copy the scripts, config
COPY src/pgsql-maintenance.sh .
RUN chmod +x pgsql-maintenance.sh

# Run the script when the container starts
ENTRYPOINT ["/bin/bash","pgsql-maintenance.sh"]
# CMD ["vacuum_db"]

