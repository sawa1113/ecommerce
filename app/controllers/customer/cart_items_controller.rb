class Customer::CartItemsController < ApplicationController
  # ログインしていないユーザーをログインページへリダイレクト
  before_action :authenticate_customer!
  before_action :set_cart_item, only: %i[increase decrease destroy]

  def index
    # ログイン中のユーザーのカートに入っている商品を取得
    @cart_items = current_customer.cart_items
    @total = @cart_items.inject(0) { |sum, cart_item| sum + cart_item.line_total }
  end

  def create
    # 商品の product_id を受け取って increase_or_create メソッドを実行
    increase_or_create(params[:cart_item][:product_id])
    # 処理が終わったらカートページ（cart_items_path）にリダイレクトし、「カートに商品を追加しました」と表示
    redirect_to cart_items_path, notice: 'カートに商品を追加しました'
  end

  def increase
    # increment!(:quantity, 1) で quantity（数量）を +1 する
    @cart_item.increment!(:quantity, 1)
    # request.referer は「直前のページ」に戻るためのもの（カートページに戻る）
    redirect_to request.referer, notice: 'カートを更新しました'
  end

  def decrease
    # decrease_or_destroy(@cart_item) を実行し、商品の数量を減らすか削除する
    decrease_or_destroy(@cart_item)
    # request.referer は「直前のページ」に戻るためのもの（カートページに戻る）
    redirect_to request.referer, notice: 'カートを更新しました'
  end

  def destroy
    # @cart_item.destroy でカート内の商品を削除。
    @cart_item.destroy
    # request.referer は「直前のページ」に戻るためのもの（カートページに戻る）
    redirect_to request.referer, notice: 'カートの商品を削除しました'
  end

  private

  def set_cart_item
    @cart_item = current_customer.cart_items.find(params[:id])
  end

  def increase_or_create(product_id)
    # カートにその product_id の商品があるか確認(カート内に商品が入っているかを確認している)
    cart_item = current_customer.cart_items.find_by(product_id:)
    if cart_item
      # すでにカート内に商品がある場合は、increment!(:quantity, 1) で数量を +1 する
      cart_item.increment!(:quantity, 1)
    else
      # カート内に商品がない場合は、 build で新しく CartItem を作成し、保存(save)する
      current_customer.cart_items.build(product_id:).save
    end
  end

  def decrease_or_destroy(cart_item)
    # もし商品の数量が 1 より多いなら → decrement!(:quantity, 1) で数量を -1
    if cart_item.quantity > 1
      cart_item.decrement!(:quantity, 1)
    else
      # もし数量が 1 なら → 商品を削除する (cart_item.destroy)
      cart_item.destroy
    end
  end
end
