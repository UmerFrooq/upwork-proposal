# frozen_string_literal: true

class BalanceManager::Deduct < ApplicationService
  attr_reader :user, :account, :amount_in_cents, :order

  def initialize(user, amount_in_cents, order)
    @user = user
    @account = user.ensure_account
    @amount_in_cents = amount_in_cents
    @order = order
  end

  def call
    response = BalanceManager::VerifyBalance.call(account, amount_in_cents)
    return response unless response.valid?

    ActiveRecord::Base.transaction do
      create_transaction!

      return ApiResponse.new(account, meta: { message: 'Your transaction was successful' })
    rescue ActiveRecord::RecordInvalid => error
      @error = error
      raise ActiveRecord::Rollback
    end

    ApiResponse.new(@error, status: 304)
  end

  private

  def create_transaction!
    Commands::CreateAccountingTransaction.call(
      account,
      -amount_in_cents,
      description,
      {
        order_id: order.id,
        transaction_for: order.order_type,
        transaction_category: AccountingTransaction.transaction_categories[:internal]
      }
    )
  end

  def description
    "Deducted amount #{round_to_currency(amount)} for order: #{order.id}"
  end

  def amount
    amount_in_cents / 100
  end
end
