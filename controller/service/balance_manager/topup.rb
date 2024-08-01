# frozen_string_literal: true

class BalanceManager::Topup < ApplicationService
  attr_reader :user, :account, :amount, :card

  def initialize(user, amount = nil, card_last4 = nil)
    @user = user
    @account ||= user.ensure_account
    @amount = (amount || @account.top_up_amount).to_f

    @card = user.cards.find_by(card_last4: card_last4)
    @card ||= @account.card
    @card ||= user.cards.where(default_source: true).first
  end

  def call
    if card.blank? || !user.card_access?(card)
      return ApiResponse.new('A valid card is necessary to Topup account.', status: 422)
    end

    charge = create_stripe_charge
    return charge unless charge.valid?

    invoice = create_stripe_invoice
    return invoice unless invoice.valid?

    order = create_order!
    create_transaction!(order, charge.data, invoice.data)
    update_account_balance!

    charge = capture_stripe_charge(charge.data.id)
    return charge unless charge.valid?

    ApiResponse.new(account, meta: charge.meta)
  end

  private

  def create_stripe_charge
    rescue_from_stripe do
      charge = StripeService.create_uncaptured_charge(
        customer_id: user.stripe_customer_id,
        amount_in_cents: amount_in_cents,
        email: user.email,
        description: description,
        metadata: metadata,
        card: card
      )
      ApiResponse.new(charge, meta: { message: 'Topup Successful' })
    end
  end

  def capture_stripe_charge(charge_id)
    rescue_from_stripe do
      charge = StripeService.capture_charge(charge_id: charge_id)
      ApiResponse.new(charge, meta: { message: 'Order placed and charge captured successfully' })
    end
  end

  def create_stripe_invoice
    rescue_from_stripe do
      StripeService.create_invoice_item(
        customer_id: user.stripe_customer_id,
        amount_in_cents: amount_in_cents,
        description: description,
        metadata: {
          user: user.id,
          user_type: user.class.name
        }
      )

      invoice = StripeService.create_invoice_without_tax(customer_id: user.stripe_customer_id)

      ApiResponse.new(invoice, meta: { message: 'Invoice Created' })
    end
  end

  def create_order!
    order = Order.new(buyer: user, order_type: Order.order_types[:topup], card_info: card_detail.as_json)
    order.complete!
    order
  end

  def create_transaction!(order, stripe_charge, stripe_invoice)
    Commands::CreateAccountingTransaction.call(
      account,
      amount_in_cents,
      description,
      {
        stripe_charge: stripe_charge,
        stripe_invoice: stripe_invoice,
        order_id: order.id,
        transaction_for: order.order_type,
        transaction_category: AccountingTransaction.transaction_categories[:external]
      }
    )
  end

  def update_account_balance!
    account.balance_in_cents = account.calculate_balance_in_cents
    account.save!
  end

  def description
    "Topup amount #{round_to_currency(amount)}"
  end

  def metadata
    {
      transaction_type: AccountingTransaction.transaction_types[:credit]
    }
  end

  def amount_in_cents
    amount * 100
  end

  def card_detail
    {
      card_type: @card.card_type,
      card_last4: @card.card_last4
    }
  end
end
