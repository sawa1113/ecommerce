# ベースイメージとして ruby:3.1.2-slim-bullseye を使用。これにより、Ruby 3.1.2 がインストールされた Debian（Bullseye）ベースの軽量なイメージが使われる。
# AS assets: このステージに名前を付けて後で利用できるようにしている。
FROM ruby:3.1.2-slim-bullseye AS assets
# Dockerイメージにメタデータを追加するための命令。ここではmaintainerというキーで、イメージのメンテナンス担当者（作成者）とメールアドレス(問い合わせ先)を指定。
LABEL maintainer="Nick Janetakis <nick.janetakis@gmail.com>"
# 作業ディレクトリを/appに設定。これ以降のコマンドはこのディレクトリ内で実行される。
WORKDIR /app
# ユーザーID (UID) とグループID (GID) を変数として指定。これにより、コンテナ内のユーザーのIDとグループIDを設定できる。
ARG UID=1000
ARG GID=1000
# いくつかの パッケージのインストールと環境設定を行う。
# apt-get update: パッケージリストの更新
# apt-get install: 必要なパッケージをインストール（build-essential, curl, git, libpq-dev など）
# Node.js と Yarn をインストールします。これらは Rails アプリのフロントエンドの依存関係に使う。
# groupadd と useradd コマンドで、新しいユーザー（ruby）を作成し、必要なアクセス権を設定する。
# /node_modules ディレクトリを作成し、ユーザー ruby に書き込み権限を付与する。
RUN bash -c "set -o pipefail && apt-get update \
  && apt-get install -y --no-install-recommends build-essential curl git libpq-dev \
  && curl -sSL https://deb.nodesource.com/setup_18.x | bash - \
  && curl -sSL https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
  && echo 'deb https://dl.yarnpkg.com/debian/ stable main' | tee /etc/apt/sources.list.d/yarn.list \
  && apt-get update && apt-get install -y --no-install-recommends nodejs yarn \
  && rm -rf /var/lib/apt/lists/* /usr/share/doc /usr/share/man \
  && apt-get clean \
  && groupadd -g \"${GID}\" ruby \
  && useradd --create-home --no-log-init -u \"${UID}\" -g \"${GID}\" ruby \
  && mkdir /node_modules && chown ruby:ruby -R /node_modules /app"
# USER ruby以降のコマンドはtubyユーザーで実行される。
USER ruby
# Gemfile と Gemfile.lock をコンテナ内にコピーします。これにより、Gem の依存関係がインストールされる。
COPY --chown=ruby:ruby Gemfile* ./
# bundle install を実行して、必要な Ruby gem をインストールする。
RUN bundle install --jobs "$(nproc)"
# package.json と Yarn 関連ファイルをコピーする。
COPY --chown=ruby:ruby package.json *yarn* ./
# yarn install を実行して、フロントエンドの依存関係をインストールする。
RUN yarn install
# RAILS_ENV と NODE_ENV を production に設定し、環境変数としてコンテナ内に設定する。
# Rails の環境設定を指定するための引数で、production に設定。これにより、Railsアプリケーションが本番環境向けにビルドされることを示している。
ARG RAILS_ENV="production"
# Node.js の環境設定を指定するための引数で、これも production に設定。Node.js を使っている場合、NODE_ENV を production に設定すると、最適化されたコードが使われ、開発用のデバッグ情報などが削除される。
ARG NODE_ENV="production"
# Railsアプリケーション内でどの環境で動作しているかを指定する。
ENV RAILS_ENV="${RAILS_ENV}" \
    # Node.js アプリケーションが production 環境で実行されることを示す。
    NODE_ENV="${NODE_ENV}" \
    # この環境変数の設定は、PATHに追加のディレクトリを加えるもの。これにより、コンテナ内で実行するコマンドやスクリプトが /home/ruby/.local/binや/node_modules/.binという場所にもアクセスできるようになる。これらは、RubyやNode.js のコマンドがインストールされる場所である場合がある。
    PATH="${PATH}:/home/ruby/.local/bin:/node_modules/.bin" \
    # コンテナ内でUSER環境変数をrubyに設定。これはコンテナ内で実行されるプロセスが、rubyユーザーとして動作することを示す。
    USER="ruby"
# 残りのアプリケーションコードをコピーする。
COPY --chown=ruby:ruby . .
# 開発環境以外であれば、アセット（画像、CSS、JavaScript）をコンパイルする。
RUN if [ "${RAILS_ENV}" != "development" ]; then \
  SECRET_KEY_BASE=dummyvalue rails assets:precompile; fi

CMD ["bash"]

###############################################################################
# assets ステージと同じベースイメージを使っていますが、このステージでは最終的なアプリケーション用の環境を作成。
FROM ruby:3.1.2-slim-bullseye AS app
LABEL maintainer="Nick Janetakis <nick.janetakis@gmail.com>"
# 作業ディレクトリを_appに設定
WORKDIR /app
# ユーザーID (UID) とグループID (GID) を変数として指定。これにより、コンテナ内のユーザーのIDとグループIDを設定できる。
ARG UID=1000
ARG GID=1000

# いくつかの パッケージのインストールと環境設定を行う。
# apt-get update:パッケージ情報を更新する。これにより、後でインストールするパッケージが最新の状態でインストールされるようになる。
RUN apt-get update \
  # apt-get install -y --no-install-recommends build-essential curl libpq-dev vim:必要なパッケージをインストールする。ここでインストールされているのは以下のパッケージ。
  # build-essential：コンパイルに必要なツール群（例えば、gccやmakeなど）を含む。
  # curl：HTTPリクエストを送るためのツール。インターネット経由でデータをダウンロードする際に使われる。
  # libpq-dev：PostgreSQLとの接続を可能にするライブラリ。RailsアプリケーションがPostgreSQLを使用する場合に必要。
  # vim：テキストエディタ。後でDockerコンテナ内でファイルを編集するためにインストールされる。
  && apt-get install -y --no-install-recommends build-essential curl libpq-dev vim \
  # rm -rf /var/lib/apt/lists/* /usr/share/doc /usr/share/man:不要なキャッシュやドキュメントファイルを削除する。これにより、イメージサイズが小さくなり、不要なファイルが含まれないようになる。
  && rm -rf /var/lib/apt/lists/* /usr/share/doc /usr/share/man \
  # apt-get clean:apt-getが使用したキャッシュを削除して、イメージのサイズをさらに小さくする。
  && apt-get clean \
  # groupadd -g "${GID}" ruby:新しいユーザーグループrubyを作成する。${GID}は引数で指定されたグループIDを使用する。
  && groupadd -g "${GID}" ruby \
  # useradd --create-home --no-log-init -u "${UID}" -g "${GID}" ruby:新しいユーザーrubyを作成する。${UID}はユーザーID、${GID}はグループIDを指定する。また、--create-homeオプションでホームディレクトリを作成し、--no-log-initでログの初期化を無効にしている。
  && useradd --create-home --no-log-init -u "${UID}" -g "${GID}" ruby \
  # chown ruby:ruby -R /app:/appディレクトリとその中のファイルの所有者を、先ほど作成したrubyユーザーとrubyグループに変更する。この操作により、アプリケーションが正しい権限で実行できるようになる。
  && chown ruby:ruby -R /app
# USER ruby以降のコマンドはtubyユーザーで実行される。
USER ruby
# アプリケーションのbinフォルダをコピー。
COPY --chown=ruby:ruby bin/ ./bin
# コピーしたbinフォルダ内のファイルに実行権限を付与。
RUN chmod 0755 bin/*
# Rails の環境設定を指定するための引数で、production に設定。これにより、Railsアプリケーションが本番環境向けにビルドされることを示している。
ARG RAILS_ENV="production"
# Railsアプリケーション内でどの環境で動作しているかを指定する。
ENV RAILS_ENV="${RAILS_ENV}" \
    # この環境変数の設定は、PATHに追加のディレクトリを加えるもの。これにより、コンテナ内で実行するコマンドやスクリプトが /home/ruby/.local/binという場所にもアクセスできるようになる。これらは、RubyやNode.js のコマンドがインストールされる場所である場合がある。
    PATH="${PATH}:/home/ruby/.local/bin" \
    # コンテナ内でUSER環境変数をrubyに設定。これはコンテナ内で実行されるプロセスが、rubyユーザーとして動作することを示す。
    USER="ruby"
# assetsステージから必要なファイル（Gem のインストール結果やコンパイルされたアセット）をコピー。
COPY --chown=ruby:ruby --from=assets /usr/local/bundle /usr/local/bundle
COPY --chown=ruby:ruby --from=assets /app/public /public
COPY --chown=ruby:ruby . .
# コンテナが起動したときに実行されるコマンドを指定。ここではdocker-entrypoint-webというスクリプトを実行。
ENTRYPOINT ["/app/bin/docker-entrypoint-web"]
# コンテナの8000ポートを開放。
EXPOSE 8000
# デフォルトでRailsサーバーを起動。
CMD ["rails", "s"]
