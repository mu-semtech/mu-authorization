FROM madnificent/elixir-server:1.9

ENV MU_SPARQL_ENDPOINT 'http://database:8890/sparql'
ENV LOG_ELIXIR_STARTUP_COMMAND 'true'

RUN sed -i "2i\\if [ -f /config/config.ex ] ; then cp /config/config.ex /app/lib/acl/user_groups/config.ex ; fi" /startup.sh
RUN sed -i "2i\\if [ -f /config/user_groups.ex ] ; then cp /config/user_groups.ex /app/lib/acl/user_groups/config.ex ; fi" /startup.sh
RUN sed -i "2i\\if [ -f /config/delta.ex ] ; then cp /config/delta.ex /app/lib/delta/config.ex ; fi" /startup.sh

COPY . /app

RUN sh /setup.sh
