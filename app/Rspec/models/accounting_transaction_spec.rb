# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccountingTransaction, type: :model do
  subject { FactoryBot.build(:accounting_transaction, :debit) }

  describe :associations do
    it { should belong_to(:account) }
  end

  describe :validations do
    describe :presence do
      it { is_expected.to validate_presence_of(:status) }
      it { is_expected.to validate_presence_of(:transaction_type) }
    end
  end
end
