class BotSendStartJob < ApplicationJob
  queue_as :bot

  rescue_from(StandardError) do |exception|
    send_error_statement(arguments[1], I18n.t('errors.bots.unknown_request_failure'))
  end

  rescue_from(Errno::ECONNREFUSED) do |exception|
    send_error_statement(arguments[1], I18n.t('errors.bots.communication_failure'))
  end

  rescue_from(RestClient::RequestFailed) do |exception|
    send_error_statement(arguments[1], I18n.t('errors.bots.bot_failure'))
  end

  def perform(bot_id, chat_session_id, user_id)
    user = User.find(user_id)
    Bot.find(bot_id).send_start(chat_session_id, user)
  rescue => e
    backtrace = ::Rails.backtrace_cleaner.clean(e.backtrace)
    Sidekiq::Logging.logger.error "bot_id:#{bot_id} failed : #{e.message}\n\t#{backtrace.join("\n\t")}"
    raise
  end


  private

    def send_error_statement(session_id, message)
      ChatStatement.create(
        speaker: ChatStatement.speakers[:moderator],
        nature: ChatStatement.natures[:notification],
        content: { text: message },
        chat_session: ChatSession.find(session_id)
      )
    end

end
