defmodule LiveSub do
  @moduledoc """
  `LiveSub` enables `LiveComponent` to communicate with other LiveComponent
  without dealing with the `LiveView`.

  Think of `LiveSub` as pub/sub for `LiveComponent`.

  ## Why

  With `LiveSub` each `LiveComponent` can operate, be defined and tested independently without
  any dependencies on the parent LiveView.

  Additionally `LiveComponent` can make async calls and calculations on it's own.

  This can lead to simpler `LiveView` application designs and LiveComponents that
  can be used in multiple LiveViews.

  ## Usage

  ### Setup
  1. Add `LiveSub` in your `Liveview`

          defmodule LiveSubExampleWeb.MyLiveview do
            use LiveSubExampleWeb, :live_view
            use LiveSub.LiveView
            ...

  2. Add your components in your `Liveview` with the `init=true` attribute
          <.live_component module={PeopleComponent} id={PeopleComponent} init={true} />

  3. And `LiveSub` in your `LiveComponent`

          defmodule LiveSubExampleWeb.PeopleComponent do
            @moduledoc false
            use LiveSubExampleWeb, :live_component
            use LiveSub.LiveComponent,
              subscribe_to: [
                "person_added",
                "people_loaded"
              ],
              omits: [
                "people_loaded"
              ]

      `subscribe_to` defines the topics the LiveComponent will be listen to

      `omits` defines the topics the LiveComponent will emit to other LiveCompoments

  ### Send messages

  When you define topics in `omits` parameter, `LiveSub` generates helper functions in your `LiveComponent`
  to publish messages.

  For example
      omits: [ "people_loaded" ]

  generates `SubHelper.pub_person_added/1` that publishes data (as its argument) to the
  topic `"people_loaded"`

      SubHelper.pub_person_added(%{name: "John", surname: "Smith"})


  ### Receive messages

  When you define topics in `subscribe_to` parameter, `LiveSub`
  will call functions in your `LiveComponent` that are generated using the name of the topic.


  The name of the function called is sub_`topic_name`, and accepts the data published and the `socket`.
  You'll need to return the `socket` and you can update the assigns.

  For example, in your `LiveComponent`:

      defmodule LiveSubExampleWeb.PeopleComponent do
        ....
        #This will be called when `SubHelper.pub_person_added` is called from a component
        def sub_people_added(person, socket) do
          socket |> assign(:person, person)
        end



  A LiveComponent can `omit` & `subscribe_to` to the same topic thus it can send messages to itself.
  This is useful for async calls.

        defmodule LiveSubExampleWeb.PeopleComponent do
          def mount(socket) do
              pid = self()

              Task.start(fn ->
                SubHelper.pub_people_loaded(Database.load_people(), pid)
              end)

            {:ok, socket}
          end
          ...
          def sub_people_loaded(people, socket) do
            socket |> assign(:people, people)
          end
        end

  ### Drawbacks:


    * `LiveSub` overrides `def update(%{id: id, init: true})` in your `LiveComponent`
    called when the component receives it's initial assigns.
    LiveSub will assign the assigns to the socket

      If you don't want that behavior, you can set `replace_initial_update` to `false` and use
      `LiveSub.LiveComponent.subscribe(component_id)` on your own.

          use LiveSub.LiveComponent,
            replace_initial_update: false

  """

  defmodule LiveComponent do
    @moduledoc false

    defmacro __using__(opts) do
      quote location: :keep, bind_quoted: [opts: opts] do
        subscribed_topics = Keyword.get(opts, :subscribe_to) || []
        omits_topics = Keyword.get(opts, :omits) || []
        replace_initial_update = Keyword.get(opts, :replace_initial_update, true)

        def update(%{id: id, init: true} = assigns, socket) do
          subscribe(id)
          {:ok, socket |> assign(assigns |> Map.delete(:init))}
        end

        defp get_function_name_from_topic(topic) do
          String.to_atom("sub_#{topic}")
        end

        defmodule SubHelper do
          @moduledoc false
          for topic <- subscribed_topics do
            def unquote(:"#{topic}_topic")() do
              unquote(topic)
            end
          end

          ## Generate all pub_ helper functions in test environment
          if Mix.env() == :test do
            for omits <- (omits_topics ++ subscribed_topics) |> Enum.uniq() do
              def unquote(:"pub_#{omits}")(data, pid \\ self()) do
                send(pid, %{lib: :live_sub, topic: unquote(omits), data: data})
              end
            end
          else
            for omits <- omits_topics do
              def unquote(:"pub_#{omits}")(data, pid \\ self()) do
                send(pid, %{lib: :live_sub, topic: unquote(omits), data: data})
              end
            end
          end
        end

        @after_compile __MODULE__

        def __after_compile__(env, _bytecode) do
          ensure_topic_functions(env)
        end

        defp ensure_topic_functions(env) do
          for topic <- unquote(subscribed_topics) do
            function_name = get_function_name_from_topic(topic)
            functions = __MODULE__.__info__(:functions)
            arity = 2

            case Keyword.get(functions, function_name) do
              ^arity ->
                nil

              _ ->
                IO.warn(
                  "#{__MODULE__} is subscribed to topic #{topic} but
                  doesn't implement function #{inspect(function_name)}\#{arity}",
                  Macro.Env.stacktrace(env)
                )
            end
          end
        end

        def subscribe(id) do
          for topic <- unquote(subscribed_topics) do
            send(self(), %{
              lib: :live_sub,
              action: :subscribe,
              topic: topic,
              module: __MODULE__,
              id: id
            })
          end
        end

        def update(%{lib: :live_sub, topic: topic, data: data}, socket) do
          {:ok, apply(__MODULE__, get_function_name_from_topic(topic), [data, socket])}
        end
      end
    end
  end

  defmodule LiveView do
    @moduledoc false
    defmacro __using__(opts) do
      quote location: :keep, bind_quoted: [opts: opts] do
        def handle_info(%{topic: topic, data: data}, socket) do
          # send
          for {module, id} <- get_components_for_topic(topic) do
            Phoenix.LiveView.send_update(module, lib: :live_sub, topic: topic, data: data, id: id)
          end

          {:noreply, socket}
        end

        def handle_info(
              %{lib: :live_sub, action: :subscribe, module: module, id: id, topic: topic},
              socket
            ) do
          subscribe(topic, module, id)

          {:noreply, socket}
        end

        defp get_topic_key(topic) do
          {:matrix, topic}
        end

        defp subscribe(topic, module, id) do
          key = get_topic_key(topic)
          Process.put(key, Enum.uniq(Process.get(key, []) ++ [{module, id}]))
        end

        defp get_components_for_topic(topic) do
          key = get_topic_key(topic)
          Process.get(key) || []
        end
      end
    end
  end
end
