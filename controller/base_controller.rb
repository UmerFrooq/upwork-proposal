# frozen_string_literal: true

class Api::V1::Clients::BaseController < ApiController

  def authorize_admin
    authorize(%w[AdminUser])
  end

  def authorize_personal_client
    authorize(%w[PersonalUser])
  end

  def authorize_client_and_business
    authorize(%w[AdminUser PersonalUser])
  end

  def authorize_all
    authorize(%w[AdminUser PersonalUser VendorUser])
  end
end
