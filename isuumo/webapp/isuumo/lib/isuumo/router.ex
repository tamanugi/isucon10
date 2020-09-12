defmodule Isuumo.Router do
  use Plug.Router

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

  # NAZOTTE_LIMIT = 50
  # ESTATE_SEARCH_CONDITION = JSON.parse(File.read('../fixture/estate_condition.json'), symbolize_names: true)

  defp success(conn, resp) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, resp |> Poison.encode!())
  end

  def error(conn) do
    send_resp(conn, 400, "")
  end

  def not_found(conn), do: send_resp(conn, 404, "")

  def query(sql) do
    SQL.query!(Isuumo.Repo, sql, [])
  end

  def range_by_id("", _), do: nil

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
    # XXX:
    sql = "SELECT * FROM chair WHERE stock > 0 ORDER BY price ASC, id ASC LIMIT #{@limit}"
    chairs = query(sql)
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
    page = Map.get(params, "page") |> String.to_integer()
    per_page = Map.get(params, "perPage") |> String.to_integer()

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
    sql = "SELECT * FROM estate ORDER BY rent ASC, id ASC LIMIT #{@limit}"
    estates = query(sql)
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

    success(conn, res)
  end

  # post '/api/estate/nazotte' do
  #   coordinates = body_json_params[:coordinates]

  #   unless coordinates
  #     logger.error "post search estate nazotte failed: coordinates not found"
  #     halt 400
  #   end

  #   if !coordinates.is_a?(Array) || coordinates.empty?
  #     logger.error "post search estate nazotte failed: coordinates are empty"
  #     halt 400
  #   end

  #   longitudes = coordinates.map { |c| c[:longitude] }
  #   latitudes = coordinates.map { |c| c[:latitude] }
  #   bounding_box = {
  #     top_left: {
  #       longitude: longitudes.min,
  #       latitude: latitudes.min,
  #     },
  #     bottom_right: {
  #       longitude: longitudes.max,
  #       latitude: latitudes.max,
  #     },
  #   }

  #   sql = 'SELECT * FROM estate WHERE latitude <= ? AND latitude >= ? AND longitude <= ? AND longitude >= ? ORDER BY popularity DESC, id ASC'
  #   estates = db.xquery(sql, bounding_box[:bottom_right][:latitude], bounding_box[:top_left][:latitude], bounding_box[:bottom_right][:longitude], bounding_box[:top_left][:longitude])

  #   estates_in_polygon = []
  #   estates.each do |estate|
  #     point = "'POINT(%f %f)'" % estate.values_at(:latitude, :longitude)
  #     coordinates_to_text = "'POLYGON((%s))'" % coordinates.map { |c| '%f %f' % c.values_at(:latitude, :longitude) }.join(',')
  #     sql = 'SELECT * FROM estate WHERE id = ? AND ST_Contains(ST_PolygonFromText(%s), ST_GeomFromText(%s))' % [coordinates_to_text, point]
  #     e = db.xquery(sql, estate[:id]).first
  #     if e
  #       estates_in_polygon << e
  #     end
  #   end

  #   nazotte_estates = estates_in_polygon.take(NAZOTTE_LIMIT)
  #   {
  #     estates: nazotte_estates.map { |e| camelize_keys_for_estate(e) },
  #     count: nazotte_estates.size,
  #   }.to_json
  # end

  get "/api/estate/:id" do
    case Isuumo.Repo.get(Isuumo.Estate, id) do
      %Isuumo.Estate{} = estate ->
        # TODO: DELETE doorHeight, doorWidth
        success(conn, estate)

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

  # post '/api/estate/req_doc/:id' do
  #   unless body_json_params[:email]
  #     logger.error 'post request document failed: email not found in request body'
  #     halt 400
  #   end

  #   id =
  #     begin
  #       Integer(params[:id], 10)
  #     rescue ArgumentError => e
  #       logger.error "post request document failed: #{e.inspect}"
  #       halt 400
  #     end

  #   estate = db.xquery('SELECT * FROM estate WHERE id = ?', id).first
  #   unless estate
  #     logger.error "Requested id's estate not found: #{id}"
  #     halt 404
  #   end

  #   status 200
  # end

  # get '/api/estate/search/condition' do
  #   ESTATE_SEARCH_CONDITION.to_json
  # end

  # get '/api/recommended_estate/:id' do
  #   id =
  #     begin
  #       Integer(params[:id], 10)
  #     rescue ArgumentError => e
  #       logger.error "Request parameter \"id\" parse error: #{e.inspect}"
  #       halt 400
  #     end

  #   chair = db.xquery('SELECT * FROM chair WHERE id = ?', id).first
  #   unless chair
  #     logger.error "Requested id's chair not found: #{id}"
  #     halt 404
  #   end

  #   w = chair[:width]
  #   h = chair[:height]
  #   d = chair[:depth]

  #   sql = "SELECT * FROM estate WHERE (door_width >= ? AND door_height >= ?) OR (door_width >= ? AND door_height >= ?) OR (door_width >= ? AND door_height >= ?) OR (door_width >= ? AND door_height >= ?) OR (door_width >= ? AND door_height >= ?) OR (door_width >= ? AND door_height >= ?) ORDER BY popularity DESC, id ASC LIMIT #{LIMIT}" # XXX:
  #   estates = db.xquery(sql, w, h, w, d, h, w, h, d, d, w, d, h).to_a

  #   { estates: estates.map { |e| camelize_keys_for_estate(e) } }.to_json
  # end
end
