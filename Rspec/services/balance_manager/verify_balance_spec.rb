# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BalanceManager::VerifyBalance, type: :service do
  let(:amount_in_cents) { 100000 }
  let(:personal_user) { FactoryBot.create(:personal_user) }
  let!(:account) { FactoryBot.create(:account, accountable: personal_user) }

  context 'add transaction and update balance' do
    before { Commands::CreateAccountingTransaction.call(account, amount_in_cents) }

    it 'should return valid response true ' do
      response = BalanceManager::VerifyBalance.call(account, amount_in_cents)

      expect(response.valid?).to eq true
    end
  end
end
