defmodule DotPromptServerWeb.StatsLive do
  use DotPromptServerWeb, :live_view

  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(1000, :tick)
    end

    {:ok,
     assign(socket,
       cache_stats: DotPrompt.cache_stats(),
       prompts: DotPrompt.list_prompts(),
       collections: DotPrompt.list_collections()
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="p-6 overflow-y-auto h-full">
      <div class="stats-container">
        <h1 class="text-2xl font-bold mb-6 text-[#14b8a6]">dot-prompt Stats</h1>

        <div class="grid grid-cols-3 gap-4 mb-8">
          <div class="bg-[#1a1e26] border border-white/5 p-4 rounded-lg">
            <div class="text-[#52586a] text-[10px] uppercase tracking-wider mb-1 font-semibold">Structural Cache</div>
            <div class="text-3xl font-bold text-[#4a9edd]"><%= @cache_stats.structural %></div>
            <div class="text-[10px] text-[#52586a] mt-1">compiled templates</div>
          </div>
          <div class="bg-[#1a1e26] border border-white/5 p-4 rounded-lg">
            <div class="text-[#52586a] text-[10px] uppercase tracking-wider mb-1 font-semibold">Fragment Cache</div>
            <div class="text-3xl font-bold text-[#1d9e75]"><%= @cache_stats.fragment %></div>
            <div class="text-[10px] text-[#52586a] mt-1">expanded fragments</div>
          </div>
          <div class="bg-[#1a1e26] border border-white/5 p-4 rounded-lg">
            <div class="text-[#52586a] text-[10px] uppercase tracking-wider mb-1 font-semibold">Vary Cache</div>
            <div class="text-3xl font-bold text-[#8b84e8]"><%= @cache_stats.vary %></div>
            <div class="text-[10px] text-[#52586a] mt-1">vary branches</div>
          </div>
        </div>

        <div class="grid grid-cols-2 gap-4">
          <div class="bg-[#1a1e26] border border-white/5 p-4 rounded-lg">
            <h2 class="text-xs font-semibold mb-3 text-[#dde1e8] uppercase tracking-widest opacity-50">Prompts</h2>
            <ul class="space-y-1">
              <%= for prompt <- @prompts do %>
                <li class="text-xs text-[#7c8494] font-mono"><%= prompt %></li>
              <% end %>
              <%= if @prompts == [] do %>
                <li class="text-xs text-[#52586a] italic">No prompts found</li>
              <% end %>
            </ul>
          </div>

          <div class="bg-[#1a1e26] border border-white/5 p-4 rounded-lg">
            <h2 class="text-xs font-semibold mb-3 text-[#dde1e8] uppercase tracking-widest opacity-50">Collections</h2>
            <ul class="space-y-1">
              <%= for collection <- @collections do %>
                <li class="text-xs text-[#7c8494] font-mono"><%= collection %>/</li>
              <% end %>
              <%= if @collections == [] do %>
                <li class="text-xs text-[#52586a] italic">No collections found</li>
              <% end %>
            </ul>
          </div>
        </div>

        <div class="mt-6 flex gap-2">
          <button phx-click="refresh" class="btn">
            Refresh
          </button>
          <button phx-click="clear_cache" class="btn bg-red-500/10 text-red-400 border-red-500/20 hover:bg-red-500/20">
            Clear All Cache
          </button>
        </div>
      </div>
    </div>
    """
  end

  def handle_info(:tick, socket) do
    {:noreply,
     assign(socket,
       cache_stats: DotPrompt.cache_stats(),
       prompts: DotPrompt.list_prompts(),
       collections: DotPrompt.list_collections()
     )}
  end

  def handle_event("refresh", _, socket) do
    {:noreply,
     assign(socket,
       cache_stats: DotPrompt.cache_stats(),
       prompts: DotPrompt.list_prompts(),
       collections: DotPrompt.list_collections()
     )}
  end

  def handle_event("clear_cache", _, socket) do
    DotPrompt.invalidate_all_cache()

    {:noreply,
     assign(socket,
       cache_stats: DotPrompt.cache_stats()
     )}
  end
end
