# frozen_string_literal: true

class AccountingTransactionSerializer < ApplicationSerializer
  attributes :uuid, :created_at, :status, :transaction_type, :transaction_for, :amount_in_cents, :amount, :formatted_amount, :currency, :description, :stripe_charge_id, :stripe_invoice_id, :created_at, :order, :trx_id, :running_balance_in_cents, :running_balance, :formatted_running_balance, :account_id, :transaction_for, :transaction_category

  belongs_to :transfer

  def formatted_amount
    round_to_currency(object.amount)
  end

  def formatted_running_balance
    round_to_currency(object.running_balance)
  end

  def currency
    'SGD'
  end

  def order
    return if instance_options[:without_order]
    return if object.order.blank?

    AccountingOrderSerializer.new(object.order, { scope: { without_nested_associations: true } })
  end

  def stripe_charge_id
    object.stripe_charge_id.presence || 'INTERNAL TRANSACTION'
  end

  def stripe_invoice_id
    object.stripe_invoice_id.presence || 'INTERNAL TRANSACTION'
  end

  def trx_id
    object.trx_id
  end
end
