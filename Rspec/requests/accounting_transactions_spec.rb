# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::Clients::AccountingTransactionsController, type: :request do
  let(:personal_user) { FactoryBot.create(:personal_user) }
  let(:doorkeeper_access_token) do
    Doorkeeper::AccessToken.create(
      resource_owner: personal_user
    )
  end
  let(:token) { StripeMock.generate_card_token(last4: "9191", exp_year: 2025) }

  context 'GET #index' do
    let(:account) { personal_user.ensure_account }

    before do
      StripeMock.start
        CardsManager::CardCreator.call(personal_user, token)
        BalanceManager::Topup.call(personal_user, 100, personal_user.cards.first.card_last4)
        BalanceManager::Topup.call(personal_user, 200, personal_user.cards.first.card_last4)

        get api_v1_clients_accounting_transactions_path, headers: headers
      StripeMock.stop
    end

    it 'returns transactions for current_user' do
      order = Order.where(buyer: personal_user).last

      expect(order.card_info['card_last4']).to eq personal_user.cards.first.card_last4
      expect(response).to have_http_status(200)
      expect(data['accounting_transactions'].count).to eq 2
      expect(data['accounting_transactions'][0]['amount']).to eq 200
    end
  end

  context 'POST #create' do
    before do
      StripeMock.start
        CardsManager::CardCreator.call(personal_user, token)

        post api_v1_clients_accounting_transactions_path, params: { topup: { amount: 250, card_last4: personal_user.cards.first.card_last4 } }, headers: headers
      StripeMock.stop
    end

    it 'will topup user account balance by given amount using given card' do
      expect(response).to have_http_status(200)
      expect(data['account']['balance_in_cents']).to eq 25000
    end
  end
end
