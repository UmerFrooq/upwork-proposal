# frozen_string_literal: true

class AccountingTransaction < ApplicationRecord
  include TransactionNumberConcern

  belongs_to :account
  belongs_to :order, optional: true
  belongs_to :transfer, optional: true

  validates :transaction_type, :status, :amount_in_cents, presence: true

  after_commit :reload_uuid, on: :create

  enum transaction_for: ORDER_TYPE.merge({ mobile_transfer: 'mobile_transfer' })

  enum transaction_category: {
    internal: 'internal',
    external: 'external'
  }

  enum transaction_type: {
    debit: 'debit',
    credit: 'credit'
  }

  enum status: {
    success: 'success',
    fail: 'fail'
  }

  def amount
    self.amount_in_cents / 100.0
  end

  def running_balance
    self.running_balance_in_cents.to_i / 100.0
  end

  def amount_in_cents=(value)
    self[:amount_in_cents] = value
    set_transaction_type(value)
  end

  def self.search_fields
    %i[id uuid stripe_charge_id stripe_invoice_id transaction_category]
  end

  def self.serializer_nested_association
    ['transfer', 'transfer.from_account', 'transfer.to_account']
  end

  def self.filter_fields
    %i[account_id order_id transaction_type transaction_for status transaction_category]
  end

  def self.associated_models_search; end

  private

  def set_transaction_type(value)
    transaction_types = AccountingTransaction.transaction_types

    if value.positive?
      self[:transaction_type] = transaction_types[:debit]
    elsif value.negative?
      self[:transaction_type] = transaction_types[:credit]
    end
  end

  def reload_uuid
    self[:uuid] = reload.uuid
  end
end
