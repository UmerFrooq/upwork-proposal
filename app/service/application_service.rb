# frozen_string_literal: true

# Base Service Object class
class ApplicationService
  def self.call(*args, &block)
    new(*args, &block).call
  end

  def rescue_from_stripe
    yield
  rescue Stripe::CardError => err
    error_response(err, 'CardError')
  rescue Stripe::RateLimitError => e
    error_response(err, 'RateLimitError')
  rescue Stripe::InvalidRequestError => err
    error_response(err, 'InvalidRequestError')
  rescue Stripe::AuthenticationError => err
    error_response(err, 'AuthenticationError')
  rescue Stripe::APIConnectionError => err
    error_response(err, 'APIConnectionError')
  rescue Stripe::StripeError => err
    error_response(err, 'StripeError')
  end

  def past_date?(start_date)
    Date.parse(start_date) < Date.today
  end

  def round_to_currency(number, round: 2)
    helper.number_to_currency(number.to_f.round(round))
  end

  def cents_to_dollar(cents)
    round_to_currency(cents / 100.0)
  end

  def helper
    @helper ||= Class.new do
      include ActionView::Helpers::NumberHelper
    end.new
  end

  private

  def error_response(err, rescued_by)
    body = err.json_body
    error = body[:error]

    custom_message = "message=#{error[:message]} | type=#{error[:type]} | code=#{error[:code]} | decline_code=#{error[:decline_code]} | rescued_by=#{rescued_by}"
    Rails.logger.tagged('STRIPE_ERROR') { Rails.logger.debug(custom_message) }
    exception = StandardError.new(custom_message)
    ExceptionNotifier.notify_exception(exception)

    response_message = "Sorry, we cannot process your payment at this point because, #{error[:message]}"
    ApiResponse.new(response_message, status: err.http_status, meta: error_detail(error))
  end

  def error_detail(error)
    {
      error: {
        message: error[:message],
        charge_id: error[:charge],
        code: error[:code],
        type: error[:type],
        decline_code: error[:decline_code],
        param: error[:param]
      }
    }
  end
end
