defmodule Isuumo.Repo do
  use Ecto.Repo,
    otp_app: :isuumo,
    adapter: Ecto.Adapters.MyXQL

  require Ecto.Query
  import Ecto.Query
  alias Isuumo.Chair

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
        nil ->
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
        nil ->
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
        nil ->
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
        nil ->
          query

        {-1, max} ->
          from(c in query,
            where: c.dept < ^max
          )

        {min, -1} ->
          from(c in query,
            where: c.dept >= ^min
          )

        {min, max} ->
          from(c in query,
            where: c.dept >= ^min,
            where: c.dept < ^max
          )
      end

    query =
      case(kind) do
        "" ->
          query

        k ->
          from(c in query,
            where: c.kind == ^k
          )
      end

    query =
      case(color) do
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
end
