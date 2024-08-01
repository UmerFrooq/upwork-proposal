# frozen_string_literal: true

module BalanceManager
  class VerifyBalance < ApplicationService
    attr_reader :account, :amount_in_cents

    def initialize(account, amount_in_cents)
      @account = account
      @amount_in_cents = amount_in_cents.to_i
    end

    def call
      if insufficient_balance?
        ApiResponse.new('Insufficient balance in account', status: 401, meta: { amount: amount_difference })
      else
        ApiResponse.new(account)
      end
    end

    private

    def amount_difference
      amount_in_cents - balance_in_cents
    end

    def insufficient_balance?
      amount_in_cents > balance_in_cents
    end

    def balance_in_cents
      account.balance_in_cents
    end
  end
end
