defmodule Match_MVPWeb.AddProductLive do
  use Match_MVPWeb, :live_view
  alias Match_MVP.Products.Product
  alias Match_MVP.Products
  alias Match_MVP.Accounts

  def mount(_params, session, socket) do
    changeset = Products.change_product_registration(%Product{})
    product_list = Products.list_products()

    socket =
      socket
      |> assign(trigger_submit: false, check_errors: false)
      |> assign(:product_list, product_list)
      |> assign(:basket, [])
      |> assign(:order_total, 0)
      |> assign_current_user(session)
      # |> assign_product()
      |> assign_form(changeset)


      {:ok, socket}
  end

  # def assign_product(socket) do
  #   socket
  #   |> assign(:product, %Product{})
  # end

  def assign_current_user(socket, session) do
    case session do
      %{"user_token" => user_token} ->
        assign_new(socket, :current_user, fn ->
          Accounts.get_user_by_session_token(user_token)
        end)

      %{} ->
        assign_new(socket, :current_user, fn -> nil end)
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "product")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end

  def handle_event("add_product", %{"product" => product_params}, socket) do
    seller_id = socket.assigns.current_user.id

    case Products.create_product(seller_id, product_params) do
      {:ok, _product} ->

        changeset = Products.change_product_registration(%Product{}, product_params)

        socket =
          socket
          |> assign_form(Map.put(changeset,:action, :validate))
          |> put_flash(:info, "success")


        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}
    end
    {:noreply, socket}
  end

  def handle_event("add_to_basket", product, socket) do
    case socket.assigns.basket do
      [] ->
        basket = [product]
        order_total = calculate_order_total(basket)
        {:noreply, socket|> assign(:basket, basket) |> assign(:order_total, order_total)}
      _ ->
        basket = socket.assigns.basket ++ [product]
        order_total = calculate_order_total(basket)
        {:noreply, socket|> assign(:basket, basket)|> assign(:order_total, order_total)}
    end
  end

  def calculate_order_total(basket) do
    item_costs = Enum.map(basket, fn item -> String.to_float(item["cost"]) end)
    Float.round(Enum.reduce(item_costs, fn item_cost, acc -> item_cost + acc end), 2)
  end
end
