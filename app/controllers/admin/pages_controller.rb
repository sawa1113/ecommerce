class Admin::PagesController < ApplicationController
  def home
    @orders, @selected = get_orders(params)
    today_orders = Order.created_today
    @today_total_orders = total_orders(today_orders)
    @today_total_sales = total_sales(today_orders)
  end

  private

  def get_orders(params)
    if !params[:status].present? || !Order.statuses.keys.to_a.include?(params[:status])
      return [Order.eager_load(:customer).latest,
              'all']
    end

    get_by_enum_value(params[:status])
  end

  def get_by_enum_value(status)
    case status
    when 'waiting_payment'
      [Order.latest.waiting_payment.eager_load(:customer), 'waiting_payment']
    when 'confirm_payment'
      [Order.latest.confirm_payment.eager_load(:customer), 'confirm_payment']
    when 'shipped'
      [Order.latest.shipped.eager_load(:customer), 'shipped']
    when 'out_of_delivery'
      [Order.latest.out_of_delivery.eager_load(:customer), 'out_of_delivery']
    when 'delivered'
      [Order.latest.delivered.eager_load(:customer), 'delivered']
    end
  end

  def total_orders(orders)
    orders.count
  end

  def total_sales(orders)
    orders.sum(:billing_amount)
  end
end
