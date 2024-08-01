# frozen_string_literal: true

module TransactionNumberConcern
  extend ActiveSupport::Concern

  def trx_id
    "#{self.class.name.first}TRX-#{self.created_at.to_formatted_s(:number)}-#{("%06d" % self.id)}"
  end
end
