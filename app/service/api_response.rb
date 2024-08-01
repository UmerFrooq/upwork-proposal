# frozen_string_literal: true

class ApiResponse
  attr_reader :data, :status, :meta

  def initialize(data, status: :ok, meta: {})
    @data = data
    @status = status
    @meta = meta
  end

  def valid?
    status == :ok
  end

  def paid?
    false
  end
end
