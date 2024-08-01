# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BalanceManager::MakeTransfer, type: :service do
  let(:amount_in_cents) { 100000 }

  let!(:personal_user) { FactoryBot.create(:personal_user) }
  let(:second_user) { FactoryBot.create(:personal_user) }

  let!(:account) { FactoryBot.create(:account, accountable: personal_user, balance_in_cents: amount_in_cents) }
  let!(:accounting_transaction) { FactoryBot.create(:accounting_transaction, account: account, amount_in_cents: amount_in_cents) }
  let(:transfer_detail) do
    [
      {
        account: second_user.ensure_account,
        amount_in_cents: transfer_amount_in_cents,
        description: Faker::Lorem.paragraph
      }
    ]
  end

  describe 'should give valid response' do
    let(:transfer_amount_in_cents) { 1000 }

    it 'when have valid values' do
      response = BalanceManager::MakeTransfer.call(personal_user, transfer_detail, second_user)

      expect(response.valid?).to be_truthy
    end
  end

  describe 'should give invalid response' do
    let(:transfer_amount_in_cents) { nil }

    it 'when have amount nil values' do
      response = BalanceManager::MakeTransfer.call(personal_user, transfer_detail, second_user)

      expect(response.valid?).to be_falsey
    end
  end
end
