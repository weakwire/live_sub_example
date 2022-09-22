defmodule LiveSubExampleWeb.MyLiveview do
  @moduledoc false
  use LiveSubExampleWeb, :live_view
  use LiveSub.LiveView
  alias LiveSubExampleWeb.{AddPersonComponent, PeopleComponent}
end

defmodule Database do
  @moduledoc false
  def load_people do
    :timer.sleep(1000)

    [
      %{name: "Maria", surname: "Yoti"},
      %{name: "Andria", surname: "Maki"},
      %{name: "Lola", surname: "Polkinsta"}
    ]
  end
end
