# frozen_string_literal: true

module BalanceManager
  class VendorTransfer < ApplicationService
    attr_reader :order, :user

    def initialize(sender, order)
      @user = sender
      @order = order
    end

    def call
      transfer_trx_details =
        vendors_items.collect do |vendor, items|
          amount_in_cents = items.collect { |item| item.amount * item.quantity }.sum.to_f * 100
          description = "Balance Transfer transaction between #{user.class.name}##{user.id} and #{vendor.class.name}##{vendor.id}"

          {
            account: vendor.ensure_account,
            amount_in_cents: amount_in_cents,
            description: description,
            order: order
          }
        end

      BalanceManager::MakeTransfer.call(user, transfer_trx_details, order, order.order_type)
    end

    private

    def vendors_items
      @vendors_items ||=
        order.order_items
             .includes(orderable: [product: [:vendor]])
             .group_by { |item| item.orderable.product.vendor }
    end
  end
end
