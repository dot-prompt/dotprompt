defmodule DotPromptServerWeb.Router do
  use DotPromptServerWeb, :router

  pipeline :api do
    plug(:accepts, ["json"])
  end

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {DotPromptServerWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  scope "/api", DotPromptServerWeb do
    pipe_through(:api)

    get("/prompts", PromptsController, :index)
    get("/collections", PromptsController, :collections)
    get("/schema/:prompt", SchemaController, :show)
    get("/schema/:prompt/:major", SchemaController, :show)
    post("/compile", CompileController, :compile)
    post("/render", RenderController, :render)
    post("/inject", InjectController, :inject)
    get("/events", EventController, :index)
  end

  scope "/", DotPromptServerWeb do
    pipe_through(:browser)

    live("/", DevUI, :index)
    live("/stats", DevUI, :cache)
    live("/cache", DevUI, :cache)
    live("/viewer", DevUI, :render)
    live("/render", DevUI, :render)
    live("/telemetry", DevUI, :telemetry)
    live("/prompts/*file", DevUI, :index)
  end
end
