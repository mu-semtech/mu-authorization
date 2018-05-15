defmodule SPARQLClient do
  def query(query, endpoint) do
    options = [recv_timeout: 50000]
    HTTPoison.post!( endpoint, ["query=" <> URI.encode_www_form(query) <> "&format=" <> URI.encode_www_form("application/sparql-results+json")], ["Content-Type": "application/x-www-form-urlencoded"], options).body |> Poison.decode!
  end
end



