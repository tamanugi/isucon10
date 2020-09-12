defmodule Isuumo.Router do
  use Plug.Router

  plug(Plug.Logger, log: :debug)

  plug(Plug.Parsers,
    parsers: [:json],
    pass: ["text/*"],
    json_decoder: Poison
  )

  plug(:match)
  plug(:dispatch)

  alias Ecto.Adapters.SQL
  alias Plug.Conn

  @limit 20
  @chair_search_condition Poison.decode!(File.read!('fixture/chair_condition.json'))
  @estate_search_condition Poison.decode!(File.read!('fixture/estate_condition.json'))
  @nazotte_limit 50

  defp success(conn, resp) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, resp |> Poison.encode!())
  end

  def error(conn) do
    send_resp(conn, 400, "")
  end

  def not_found(conn), do: send_resp(conn, 404, "")

  def range_by_id("", _), do: {}

  def range_by_id(key, type) do
    @chair_search_condition
    |> Map.get(type)
    |> Map.get("ranges")
    |> Enum.filter(fn %{"id" => id, "min" => _, "max" => _} ->
      id == String.to_integer(key)
    end)
    |> Enum.map(fn %{"id" => _, "min" => min, "max" => max} -> {min, max} end)
    |> List.first()
  end

  def estate_range_by_id("", _), do: nil

  def estate_range_by_id(key, type) do
    @estate_search_condition
    |> Map.get(type)
    |> Map.get("ranges")
    |> Enum.filter(fn %{"id" => id, "min" => _, "max" => _} ->
      id == String.to_integer(key)
    end)
    |> Enum.map(fn %{"id" => _, "min" => min, "max" => max} -> {min, max} end)
    |> List.first()
  end

  def camelize_keys_for_estate(estates) when is_list(estates) do
    estates
    |> Enum.map(fn e -> camelize_keys_for_estate(e) end)
  end

  def camelize_keys_for_estate(%Isuumo.Estate{} = estate) do
    {dh, estate} = Map.pop(estate, :door_height)
    {dw, estate} = Map.pop(estate, :door_width)

    estate
    |> Map.put_new(:doorHeight, dh)
    |> Map.put_new(:doorWidth, dw)
  end

  post "/initialize" do
    ~w(0_Schema.sql 1_DummyEstateData.sql 2_DummyChairData.sql)
    |> Enum.each(fn filename ->
      File.read!("db/#{filename}")
      |> String.split(";")
      |> Enum.filter(fn s -> String.last(s) > 10 end)
      |> Enum.each(fn s ->
        SQL.query(Isuumo.Repo, s, [])
      end)
    end)

    success(conn, %{language: "elixir"})
  end

  get "/api/chair/low_priced" do
    chairs = Isuumo.Repo.chair_low_priced(@limit)
    success(conn, %{chairs: chairs})
  end

  get "/api/chair/search" do
    conn = Conn.fetch_query_params(conn)
    params = conn.query_params

    price_range = range_by_id(Map.get(params, "priceRangeId"), "price")
    height_range = range_by_id(Map.get(params, "heightRangeId"), "height")
    width_range = range_by_id(Map.get(params, "widthRangeId"), "width")
    dept_range = range_by_id(Map.get(params, "depthRangeId"), "depth")
    color = Map.get(params, "color")
    kind = Map.get(params, "kind")
    features = Map.get(params, "features") |> String.split(",")

    page =
      try do
        Map.get(params, "page") |> String.to_integer()
      rescue
        _ -> nil
      end

    per_page =
      try do
        Map.get(params, "perPage") |> String.to_integer()
      rescue
        _ -> nil
      end

    if price_range == nil or height_range == nil or width_range == nil or dept_range == nil or
         page == nil or per_page == nil do
      error(conn)
    else
      res =
        Isuumo.Repo.search_chair(
          price_range,
          height_range,
          width_range,
          dept_range,
          kind,
          color,
          features,
          page,
          per_page
        )

      success(conn, res)
    end
  end

  get "/api/chair/:id" do
    case Isuumo.Repo.get(Isuumo.Chair, id) do
      %Isuumo.Chair{stock: stock} = chair when stock > 0 ->
        success(conn, chair)

      _ ->
        not_found(conn)
    end
  end

  # post '/api/chair' do
  #   if !params[:chairs] || !params[:chairs].respond_to?(:key) || !params[:chairs].key?(:tempfile)
  #     logger.error 'Failed to get form file'
  #     halt 400
  #   end

  #   transaction('post_api_chair') do
  #     CSV.parse(params[:chairs][:tempfile].read, skip_blanks: true) do |row|
  #       sql = 'INSERT INTO chair(id, name, description, thumbnail, price, height, width, depth, color, features, kind, popularity, stock) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
  #       db.xquery(sql, *row.map(&:to_s))
  #     end
  #   end

  #   status 201
  # end

  post "/api/chair/buy/:id" do
    with %{"email" => _email} <- conn.body_params,
         iid when is_integer(iid) <- String.to_integer(id) do
      Isuumo.Repo.transaction(fn ->
        with %Isuumo.Chair{stock: s} when s > 0 <- Isuumo.Repo.get_chair_for_updte(iid) do
          Isuumo.Repo.query!("UPDATE chair SET stock = stock - 1 WHERE id = ?", [iid])
          success(conn, "")
        else
          _ ->
            IO.puts("not stock")
            raise "error"
        end
      end)
    else
      _ -> error(conn)
    end
  end

  get "/api/chair/search/condition" do
    success(conn, @chair_search_condition)
  end

  get "/api/estate/low_priced" do
    estates = Isuumo.Repo.estate_low_priced(@limit) |> camelize_keys_for_estate()
    success(conn, %{estates: estates})
  end

  get "/api/estate/search" do
    conn = Conn.fetch_query_params(conn)
    params = conn.query_params

    door_height_range = estate_range_by_id(Map.get(params, "doorHeightRangeId"), "doorHeight")
    door_width_range = estate_range_by_id(Map.get(params, "doorWidthRangeId"), "doorWidth")
    rent_range = estate_range_by_id(Map.get(params, "rentRangeId"), "rent")
    features = Map.get(params, "features") |> String.split(",")
    page = Map.get(params, "page") |> String.to_integer()
    per_page = Map.get(params, "perPage") |> String.to_integer()

    res =
      Isuumo.Repo.search_estate(
        door_height_range,
        door_width_range,
        rent_range,
        features,
        page,
        per_page
      )
      |> camelize_keys_for_estate()

    success(conn, res)
  end

  post "/api/estate/nazotte" do
    %{"coordinates" => coordinates} = conn.body_params
    # TODO: error handling

    [longitude_min, latitude_min, longitude_max, latitude_max] =
      coordinates
      |> Enum.reduce(nil, fn %{"latitude" => latitude, "longitude" => longitude}, acc ->
        case acc do
          [long_min, lat_min, long_max, lat_max] ->
            [
              Enum.min([long_min, longitude]),
              Enum.min([lat_min, latitude]),
              Enum.max([long_max, longitude]),
              Enum.max([lat_max, latitude])
            ]

          nil ->
            [longitude, latitude, longitude, latitude]
        end
      end)

    estates =
      Isuumo.Repo.search_estitate_form_bounding_box(
        longitude_min,
        latitude_min,
        longitude_max,
        latitude_max
      )

    coordinates_text =
      coordinates
      |> Enum.map(fn %{"latitude" => latitude, "longitude" => longitude} ->
        "#{latitude} #{longitude}"
      end)
      |> Enum.join(",")

    coordinates_to_text = "'POLYGON((#{coordinates_text}))'"

    nazotte_estates =
      estates
      |> Enum.map(fn e ->
        point = "'POINT(#{e.latitude} #{e.longitude})'"

        sql = """
        SELECT * FROM estate WHERE id = ? AND ST_Contains(ST_PolygonFromText(#{
          coordinates_to_text
        }), ST_GeomFromText(#{point}))
        """

        Isuumo.Repo.query!(sql, [e.id])
      end)
      |> Enum.filter(fn e -> e != nil end)
      |> Enum.take(@nazotte_limit)

    success(conn, %{
      estates: nazotte_estates |> camelize_keys_for_estate(),
      count: length(nazotte_estates)
    })
  end

  get "/api/estate/:id" do
    case Isuumo.Repo.get(Isuumo.Estate, id) do
      %Isuumo.Estate{} = estate ->
        success(conn, camelize_keys_for_estate(estate))

      _ ->
        not_found(conn)
    end
  end

  # post '/api/estate' do
  #   unless params[:estates]
  #     logger.error 'Failed to get form file'
  #     halt 400
  #   end

  #   transaction('post_api_estate') do
  #     CSV.parse(params[:estates][:tempfile].read, skip_blanks: true) do |row|
  #       sql = 'INSERT INTO estate(id, name, description, thumbnail, address, latitude, longitude, rent, door_height, door_width, features, popularity) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
  #       db.xquery(sql, *row.map(&:to_s))
  #     end
  #   end

  #   status 201
  # end

  post "/api/estate/req_doc/:id" do
    with %{"email" => _email} <- conn.body_params,
         iid when is_integer(iid) <- String.to_integer(id) do
      with %Isuumo.Estate{} <- Isuumo.Repo.get(Isuumo.Estate, iid) do
        success(conn, "")
      else
        _ -> not_found(conn)
      end
    else
      _ -> error(conn)
    end
  end

  get "/api/estate/search/condition" do
    success(conn, @estate_search_condition)
  end

  get "/api/recommended_estate/:id" do
    with iid <- String.to_integer(id) do
      with %Isuumo.Chair{width: w, height: h, depth: d} <- Isuumo.Repo.get(Isuumo.Chair, iid) do
        estates = Isuumo.Repo.estate_by_door_size(w, h, d)
        success(conn, camelize_keys_for_estate(estates))
      else
        _ -> not_found(conn)
      end
    else
      _ -> error(conn)
    end
  end
end
