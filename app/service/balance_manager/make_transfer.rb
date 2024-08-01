# frozen_string_literal: true

module BalanceManager
  class MakeTransfer < ApplicationService
    attr_reader :sender, :sender_account, :receiver_details, :transaction_for, :loggable, :transaction_details

    def initialize(sender, receiver_details, loggable, transaction_for = nil, transaction_details = [])
      @sender = sender
      @sender_account = sender.ensure_account
      @receiver_details = receiver_details
      @transaction_for ||= AccountingTransaction.transaction_fors[:transfer]
      @loggable = loggable
      @transaction_details = transaction_details
    end

    def call
      ActiveRecord::Base.transaction do
        make_transfer!
        return ApiResponse.new(make_transfer!)
      rescue ActiveRecord::RecordInvalid => error
        @error = error
        raise ActiveRecord::Rollback
      end

      ErrorLog.create!(
        user: sender,
        loggable: loggable,
        error_message: "Transfer for #{loggable.class.name} ##{loggable.id} Failed!"
      )

      ApiResponse.new(@error, status: :unprocessable_entity)
    end

    private

    def make_transfer!
      receiver_details.collect do |receiver_detail|
        # transaction_details sending separately for individual transfer
        # but sending with receiver detail for bulk vendor transfer
        trx_detail = transaction_details.presence || receiver_detail[:transaction_details].presence || []

        transfer = Transfer.create!(
          from_account: sender_account,
          to_account: receiver_detail.dig(:account, :id),
          amount_in_cents: receiver_detail[:amount_in_cents],
          description: receiver_detail[:description],
          transaction_details: trx_detail
        )

        deduct_balance_from_sender!(transfer.id, receiver_detail)
        add_balance_to_receiver!(transfer.id, receiver_detail)

        transfer
      end
    end

    def deduct_balance_from_sender!(transfer_id, receiver_detail)
      amount_in_cents = receiver_detail[:amount_in_cents]

      create_transaction!(
        transfer_id,
        -amount_in_cents,
        debit_description(amount_in_cents),
        sender_account,
        receiver_detail[:order]&.id
      )
    end

    def add_balance_to_receiver!(transfer_id, receiver_detail)
      amount_in_cents = receiver_detail[:amount_in_cents]
      receiver_account = receiver_detail[:account]

      create_transaction!(
        transfer_id,
        amount_in_cents,
        credit_description(amount_in_cents, receiver_account),
        receiver_account,
        receiver_detail[:order]&.id,
      )
    end

    def debit_description(amount_in_cents)
      "Deducted #{cents_to_dollar(amount_in_cents)} From Account #{sender.full_name}##{sender_account.id} against #{loggable.class.name}: #{loggable.id}"
    end

    def credit_description(amount_in_cents, receiver_account)
      receiver = receiver_account.accountable

      "Added #{cents_to_dollar(amount_in_cents)} To Account #{receiver.full_name}##{receiver_account.id} against #{loggable.class.name}: #{loggable.id}"
    end

    def create_transaction!(transfer_id, total_amount_in_cents, description, account, order_id = nil)
      Commands::CreateAccountingTransaction.call(
        account,
        total_amount_in_cents,
        description,
        {
          transaction_for: transaction_for,
          transfer_id: transfer_id,
          transaction_category: AccountingTransaction.transaction_categories[:internal],
          order_id: order_id
        }
      )
    end
  end
end
