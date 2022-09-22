defmodule LiveSubExampleWeb.PageController do
  use LiveSubExampleWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
