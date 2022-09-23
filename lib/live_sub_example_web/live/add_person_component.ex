defmodule LiveSubExampleWeb.AddPersonComponent do
  @moduledoc false
  use LiveSubExampleWeb, :live_component

  # subscribe to the liveview topic "PersonAdded"
  use LiveSub.LiveComponent,
    emits: [
      "person_added"
    ]

  def render(assigns) do
    ~H"""
    <div>
      <button
        phx-click="add_person"
        phx-target={@myself}
        type="button"
        class="inline-flex items-center rounded-md border border-transparent bg-indigo-100 px-6 py-3 text-base font-medium text-indigo-700 hover:bg-indigo-200 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
      >
        Add <%= "#{assigns.person.name}, #{assigns.person.surname}" %>
      </button>
    </div>
    """
  end

  def handle_event("add_person", _, socket) do
    # add person in the database
    # Database.insert....

    # Inform the Liveview that a new person is added on the appropriate topic
    # A helper function is generated based on the `emits` param
    SubHelper.pub_person_added(socket.assigns.person)

    {:noreply, socket}
  end
end
