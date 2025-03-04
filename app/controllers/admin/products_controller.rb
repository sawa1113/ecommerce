class Admin::ProductsController < ApplicationController
  # 商品を閲覧・作成・編集する機能はログイン済の管理者のみ権限を付与するのでauthenticate_admin!メソッドを記載。
  before_action :authenticate_admin!
  # 共通するアクションはメソッドでまとめて記載。
  before_action :set_product, only: %i[show edit update]

  def index
    @products = Product.all
  end

  def show; end

  def new
    @product = Product.new
  end

  def create
    @product = Product.new(product_params)
    if @product.save
      redirect_to admin_product_path(@product)
    else
      render :new
    end
  end

  def edit; end

  def update
    if @product.update(product_params)
      redirect_to admin_product_path(@product)
    else
      render :edit
    end
  end

  private

  def set_product
    @product = Product.find(params[:id])
  end

  def product_params
    params.require(:product).permit(:name, :description, :price, :stock, :image)
  end
end
