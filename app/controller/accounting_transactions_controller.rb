# frozen_string_literal: true

class Api::V1::Clients::AccountingTransactionsController < Api::V1::Clients::BaseController
  before_action :authorize_client_and_business
  before_action :set_account

  def index
    accounting_transactions = @account.accounting_transactions.success.latest
    accounting_transactions = FindQuery.new(accounting_transactions, params).call

    json_response(
      accounting_transactions.includes(transfer: [:from_account, :to_account], order: [:buyer]),
      each_serializer: AccountingTransactionSerializer,
      page: page,
      per: per_page
    )
  end

  def create
    result = BalanceManager::Topup.call(current_resource_owner, topup_params[:amount], topup_params[:card_last4])

    if result.valid?
      json_response(result.data, includes: [accounting_transactions: :order], meta: result.meta)
    else
      error_response(result.data, meta: result.meta)
    end
  end

  private

  def set_account
    @account = current_resource_owner.ensure_account
  end

  def topup_params
    params.require(:topup).permit(:amount, :card_last4)
  end
end
