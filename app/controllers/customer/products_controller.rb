class Customer::ProductsController < ApplicationController
  def index
    @products, @sort = get_products(params)
  end

  def show
    @product = Product.find(params[:id])
  end

  private

  def get_products(params)
    # 1. 最新の商品や価格順などの条件がない場合は、すべての商品と 'default' を返す
    return Product.all, 'default' unless params[:latest] || params[:price_high_to_low] || params[:price_low_to_high]
    # 2. 'latest' が指定されている場合、最新の商品リストと 'latest' を返す
    return Product.latest, 'latest' if params[:latest]
    # 3. 'price_high_to_low' が指定されている場合、高価格順の商品リストと 'price_high_to_low' を返す
    return Product.price_high_to_low, 'price_high_to_low' if params[:price_high_to_low]
    # 4. 'price_low_to_high' が指定されている場合、低価格順の商品リストと 'price_low_to_high' を返す
    return Product.price_low_to_high, 'price_low_to_high' if params[:price_low_to_high]
  end
end
