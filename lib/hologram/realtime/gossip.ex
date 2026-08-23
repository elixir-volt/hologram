defmodule Hologram.Realtime.Gossip do
  @moduledoc false

  # Shared gossip wiring for the per-node ETS stores (`Hologram.Realtime.Tombstone` and
  # `Hologram.Realtime.Handshake`): asking peers for what they hold, and answering when
  # they ask. Each store owns its own table, gossip topic, TTL, and merge rule.
  #
  # Nothing here waits. A reply is a message the asking store merges whenever it lands,
  # so a store is never held up by peers that are slow or absent.

  @doc false
  @spec __using__(keyword) :: Macro.t()
  defmacro __using__(opts) do
    gossip = __MODULE__
    gossip_topic = Keyword.fetch!(opts, :topic)

    quote do
      @doc false
      @spec handle_info(:sweep_expired | {:nodedown, node} | {:nodeup, node}, state) ::
              {:noreply, state}
            when node: node, state: any
      @impl GenServer
      def handle_info(:sweep_expired, state) do
        unquote(gossip).handle_sweep(state, &delete_expired/0, &schedule_sweep/0)
      end

      @impl GenServer
      def handle_info({:nodedown, _node}, state) do
        unquote(gossip).handle_nodedown(state)
      end

      @impl GenServer
      def handle_info({:nodeup, node}, state) do
        unquote(gossip).handle_nodeup(node, unquote(gossip_topic), state)
      end
    end
  end

  @doc """
  Asks every currently connected node for what it holds, and returns immediately.

  A peer answers by sending a `{:sync_reply, entries}` message, which arrives at the
  caller like any other message. A store that asks this way stays available while its
  peers answer, and merges what arrives in its `handle_info/2` - the same way it merges
  the entries peers gossip to it in steady state. A batch that arrives at boot is only
  a larger batch, not a different kind of event.

  Each node is asked directly rather than through a topic broadcast. A broadcast reaches
  whoever the topic's group membership currently names, and that membership propagates on
  its own schedule - a store asking as its node joins can broadcast into a group that
  does not list its peers yet, and hear nothing back. `Node.list/0` needs only the
  distribution connection, so this asks exactly the nodes that can answer.

  A node with no peers connected asks nobody, which costs it nothing. Peers that connect
  later are picked up by the store's `{:nodeup, node}` handling instead.
  """
  @spec request_sync(String.t()) :: :ok
  def request_sync(gossip_topic) do
    Enum.each(Node.list(), &request_sync_from(&1, gossip_topic))
  end

  @doc """
  Asks one node for what it holds, and returns immediately.

  Used when a node joins, where the newcomer and the node that saw it join are the only
  two that can hold state the other is missing. Asking the whole topic instead would
  have every node dump its entire table to every other node on every join, which grows
  quadratically with the cluster for state all but one of them already has.
  """
  @spec request_sync_from(node, String.t()) :: :ok
  def request_sync_from(node, gossip_topic) do
    Phoenix.PubSub.direct_broadcast(
      node,
      Hologram.PubSub,
      gossip_topic,
      {:sync_request, self()}
    )
  end

  @doc false
  @spec handle_sweep(state, (-> any), (-> any)) :: {:noreply, state} when state: any
  def handle_sweep(state, delete_expired, schedule_sweep) do
    delete_expired.()
    schedule_sweep.()

    {:noreply, state}
  end

  @doc false
  @spec handle_nodedown(state) :: {:noreply, state} when state: any
  def handle_nodedown(state), do: {:noreply, state}

  @doc false
  @spec handle_nodeup(node, String.t(), state) :: {:noreply, state} when state: any
  def handle_nodeup(node, gossip_topic, state) do
    request_sync_from(node, gossip_topic)
    {:noreply, state}
  end

  @doc """
  Replies to a peer's `{:sync_request, requester_pid}` by sending the full
  contents of `table_name` back as a `{:sync_reply, entries}` message.
  """
  @spec reply_to_sync_request(atom, pid) :: :ok
  def reply_to_sync_request(table_name, requester_pid) do
    send(requester_pid, {:sync_reply, :ets.tab2list(table_name)})

    :ok
  end
end
