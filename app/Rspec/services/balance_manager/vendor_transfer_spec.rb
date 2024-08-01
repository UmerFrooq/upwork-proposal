# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BalanceManager::VendorTransfer, type: :service do
  let(:amount_in_cents) { 1000000 }
  let(:personal_user) { FactoryBot.create(:personal_user) }
  let!(:order) { FactoryBot.create(:order, buyer: personal_user) }
  let!(:products) { FactoryBot.create_list(:product_with_associations, 2) }

  let(:order_items) { FactoryBot.create(:order_item, order: order) }
  let!(:account) { FactoryBot.create(:account, accountable: personal_user) }

  let!(:order_items) do
    products.each do |product|
      FactoryBot.create(:order_item, order: order, amount: product.items.first.amount, orderable: product.items.first)
    end
  end

  before { Commands::CreateAccountingTransaction.call(account, amount_in_cents) }

  it 'should transfer successfully' do
    response = BalanceManager::VerifyBalance.call(personal_user.account, 1000)
    expect(response.valid?).to eq true

    response = BalanceManager::VendorTransfer.call(personal_user, order)
    expect(response.valid?).to eq true
  end
end
