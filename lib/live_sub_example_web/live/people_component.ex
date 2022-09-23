defmodule LiveSubExampleWeb.PeopleComponent do
  @moduledoc false
  use LiveSubExampleWeb, :live_component

  use LiveSub.LiveComponent,
    subscribe_to: [
      "person_added",
      "people_loaded"
    ],
    emits: [
      "people_loaded"
    ]

  def mount(socket) do
    load_users_async()

    {:ok,
     socket
     |> assign(:people, [])
     |> assign(:loading, true)}
  end

  defp load_users_async do
    pid = self()

    Task.start(fn ->
      # `SubHelper.pub_people_loaded` is generated as emits: people_loaded is defined.
      # It informs the liveview of the loaded people.
      # pid is the LiveView pid as we are using a task here to load data on mount
      SubHelper.pub_people_loaded(Database.load_people(), pid)
    end)
  end

  def handle_event("load_users", _, socket) do
    load_users_async()

    {:noreply, socket |> assign(:loading, true)}
  end

  @doc """
  The `sub_people_loaded\2` will be called since the LiveComponent
  is subscribed_to "people_loaded" topic
  """
  def sub_people_loaded(people, socket) do
    socket |> append_people(people) |> assign(:loading, false)
  end

  @doc """
  The `sub_person_added\2` will be called since the LiveComponent
  is subscribed_to "person_added" topic
  """
  def sub_person_added(person, socket) do
    socket |> append_people([person])
  end

  defp append_people(socket, people) do
    socket |> assign(:people, socket.assigns[:people] ++ people)
  end
end
