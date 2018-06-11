FROM madnificent/elixir-server:1.6.5

ENV MU_SPARQL_ENDPOINT 'http://database:8890/sparql'

COPY . /app

RUN sh /setup.sh
