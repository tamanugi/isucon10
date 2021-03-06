defmodule Isuumo.Repo do
  use Ecto.Repo,
    otp_app: :isuumo,
    adapter: Ecto.Adapters.MyXQL

  require Ecto.Query
  import Ecto.Query
  alias Isuumo.Chair
  alias Isuumo.Estate

  def chair_low_priced(limit) do
    from(c in Chair, where: c.stock > 0, order_by: [asc: c.price, asc: c.id], limit: ^limit)
    |> all()
  end

  def estate_low_priced(limit) do
    from(c in Estate, order_by: [asc: c.rent, asc: c.id], limit: ^limit)
    |> all()
  end

  def search_chair(
        price_range,
        height_range,
        width_range,
        dept_range,
        kind,
        color,
        features,
        page,
        limit
      ) do
    query = from(c in Chair, where: c.stock > 0, order_by: [desc: c.popularity, asc: c.id])

    query =
      case(price_range) do
        {} ->
          query

        {-1, max} ->
          from(c in query,
            where: c.price < ^max
          )

        {min, -1} ->
          from(c in query,
            where: c.price >= ^min
          )

        {min, max} ->
          from(c in query,
            where: c.price >= ^min,
            where: c.price < ^max
          )
      end

    query =
      case(height_range) do
        {} ->
          query

        {-1, max} ->
          from(c in query,
            where: c.height < ^max
          )

        {min, -1} ->
          from(c in query,
            where: c.height >= ^min
          )

        {min, max} ->
          from(c in query,
            where: c.height >= ^min,
            where: c.height < ^max
          )
      end

    query =
      case(width_range) do
        {} ->
          query

        {-1, max} ->
          from(c in query,
            where: c.width < ^max
          )

        {min, -1} ->
          from(c in query,
            where: c.width >= ^min
          )

        {min, max} ->
          from(c in query,
            where: c.width >= ^min,
            where: c.width < ^max
          )
      end

    query =
      case(dept_range) do
        {} ->
          query

        {-1, max} ->
          from(c in query,
            where: c.depth < ^max
          )

        {min, -1} ->
          from(c in query,
            where: c.depth >= ^min
          )

        {min, max} ->
          from(c in query,
            where: c.depth >= ^min,
            where: c.depth < ^max
          )
      end

    query =
      case(kind) do
        nil ->
          query

        "" ->
          query

        k ->
          from(c in query,
            where: c.kind == ^k
          )
      end

    query =
      case(color) do
        nil ->
          query

        "" ->
          query

        k ->
          from(c in query,
            where: c.color == ^k
          )
      end

    query =
      if length(features) > 0 do
        Enum.reduce(features, query, fn f, acc ->
          like = "%#{f}%"

          from(c in acc,
            where: like(c.features, ^like)
          )
        end)
      else
        query
      end

    # count
    count_query = from(c in query, select: count(c.id))

    # paginate
    query =
      from(c in query,
        limit: ^limit,
        offset: ^(page * limit)
      )

    %{
      count: count_query |> first() |> one(),
      chairs: query |> all()
    }
  end

  def get_chair_for_updte(id) do
    from(c in Isuumo.Chair, where: c.id == ^id)
    |> lock("FOR UPDATE")
    |> one()
  end

  def search_estate(
        door_height_range,
        door_width_range,
        rent_range,
        features,
        page,
        limit
      ) do
    query = from(c in Estate, order_by: [desc: c.popularity, asc: c.id])

    query =
      case(door_height_range) do
        nil ->
          query

        {-1, max} ->
          from(c in query,
            where: c.door_height < ^max
          )

        {min, -1} ->
          from(c in query,
            where: c.door_height >= ^min
          )

        {min, max} ->
          from(c in query,
            where: c.door_height >= ^min,
            where: c.door_height < ^max
          )
      end

    query =
      case(door_width_range) do
        nil ->
          query

        {-1, max} ->
          from(c in query,
            where: c.door_width < ^max
          )

        {min, -1} ->
          from(c in query,
            where: c.door_width >= ^min
          )

        {min, max} ->
          from(c in query,
            where: c.door_width >= ^min,
            where: c.door_width < ^max
          )
      end

    query =
      case(rent_range) do
        nil ->
          query

        {-1, max} ->
          from(c in query,
            where: c.rent < ^max
          )

        {min, -1} ->
          from(c in query,
            where: c.rent >= ^min
          )

        {min, max} ->
          from(c in query,
            where: c.rent >= ^min,
            where: c.rent < ^max
          )
      end

    query =
      if length(features) > 0 do
        Enum.reduce(features, query, fn f, acc ->
          like = "%#{f}%"

          from(c in acc,
            where: like(c.features, ^like)
          )
        end)
      else
        query
      end

    # count
    count_query = from(c in query, select: count(c.id))

    # paginate
    query =
      from(c in query,
        limit: ^limit,
        offset: ^(page * limit)
      )

    %{
      count: count_query |> first() |> one(),
      estates: query |> all()
    }
  end

  def search_estitate_form_bounding_box(longitude_min, latitude_min, longitude_max, latitude_max) do
    from(c in Isuumo.Estate,
      where: c.longitude >= ^longitude_min,
      where: c.longitude <= ^longitude_max,
      where: c.latitude >= ^latitude_min,
      where: c.latitude <= ^latitude_max
    )
    |> all()
  end

  def estate_by_door_size(w, h, d, limit) do
    # ORDER BY popularity DESC, id ASC LIMIT #{LIMIT}"
    from(c in Estate,
      where:
        (c.door_width >= ^w and c.door_height >= ^h) or
          (c.door_width >= ^w and c.door_height >= ^d) or
          (c.door_width >= ^h and c.door_height >= ^w) or
          (c.door_width >= ^h and c.door_height >= ^d) or
          (c.door_width >= ^d and c.door_height >= ^w) or
          (c.door_width >= ^d and c.door_height >= ^h),
      order_by: [desc: c.popularity, asc: c.id],
      limit: ^limit
    )
    |> all()
  end
end
