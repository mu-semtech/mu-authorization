defmodule SparqlClient do
  def default_endpoint do
    "http://localhost:8890/sparql"
  end

  def query(query, endpoint\\default_endpoint) do
    options = [recv_timeout: 50000]
    HTTPoison.post!( endpoint, ["query=" <> URI.encode_www_form(query) <> "&format=" <> URI.encode_www_form("application/sparql-results+json")], ["Content-Type": "application/x-www-form-urlencoded"], options).body |> Poison.decode!
  end

  def extract_results( parsed_response ) do
    parsed_response
    |> Map.get("results")
    |> Map.get("bindings")
  end
end



