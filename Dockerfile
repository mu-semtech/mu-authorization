FROM madnificent/elixir-server:1.6.5

ENV MU_SPARQL_ENDPOINT 'http://database:8890/sparql'

RUN sed -i "2i\\cp /config/config.ex /app/lib/acl/user_groups/config.ex" /startup.sh

COPY . /app

RUN sh /setup.sh
