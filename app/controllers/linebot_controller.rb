class LinebotController < ApplicationController
  require 'line/bot'  # gem 'line-bot-api'
  require 'httpclient' # gem 'httpclient'

  # callbackアクションのCSRFトークン認証を無効
  protect_from_forgery :except => [:callback]

  def initialize
    @url = 'https://qiita.com/api/v2/items?'
    @header = {Authorization: "Bearer " + ENV["QIITA_ACCESS_TOKEN"]}
  end

  def client
    @client ||= Line::Bot::Client.new { |config|
      config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
      config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
    }
  end

  def callback
    body = request.body.read
    signature = request.env['HTTP_X_LINE_SIGNATURE']

    unless client.validate_signature(body, signature)
      head :bad_request
    end

    events = client.parse_events_from(body)
    events.each do |event|
      case event
      when Line::Bot::Event::Message
        case event.type
        when Line::Bot::Event::MessageType::Text
          # 検索条件の作成
          # 「stock数が50以上 かつ 入力文字に合致する」を検索条件とする
          queryText = "query=stocks%3A>50+"
          queryText += event.message['text']
          # urlに検索条件を付与する
          @url += queryText
          httpClient = HTTPClient.new
          # QiitaとAPI通信をし、検索文をGetで投げる
          # その投げた結果を受け取る
          response = httpClient.get(@url, header: @header)
          result = JSON.parse(response.body)
          # 検索結果をソートする
          # いいねが大きい順に並べ替え、先頭から10件を取得する
          sort_result = result.sort{|x,y| x['likes_count'] <=> y['likes_count']}.reverse.first(10)

          # 取得したQiita記事のタイトルとURLを取得し、文字列にする
          reply_text = ""
          sort_result.each do |each_re|
            reply_text += each_re["title"]
            reply_text += "\n"
            reply_text += each_re["url"]
            reply_text += "\n"
          end

          # LINEにレスポンスとしてQiita記事を返却する
          message = {
            type: 'text',
            text: reply_text
          }
          client.reply_message(event['replyToken'], message)
        end
      end
    end
  end

  
  # おうむ返しBotを作成した時のcallbackメソッド
  # def callback
  #   body = request.body.read

  #   signature = request.env['HTTP_X_LINE_SIGNATURE']
  #   unless client.validate_signature(body, signature)
  #     head :bad_request
  #   end

  #   events = client.parse_events_from(body)

  #   events.each { |event|
  #     case event
  #     when Line::Bot::Event::Message
  #       case event.type
  #       when Line::Bot::Event::MessageType::Text
  #         message = {
  #           type: 'text',
  #           text: event.message['text']
  #         }
  #         client.reply_message(event['replyToken'], message)
  #       end
  #     end
  #   }

  #   head :ok
  # end
end
