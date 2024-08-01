# frozen_string_literal: true

class ApiController < ActionController::API
  respond_to :json
  include ActionController::MimeResponds
  include SortConcern
  include Base64ToFile
  include Response

  unless Rails.env.test?
    before_action :prepare_exception_notifier
    before_action :update_user_activity
  end

  include ExceptionHandler

  def current_resource_owner
    if doorkeeper_token
      doorkeeper_token
        .resource_owner_type
        .constantize
        .find(doorkeeper_token.resource_owner_id)
    end
  end

  def prepare_exception_notifier
    request.env['exception_notifier.exception_data'] = {
      current_user: current_resource_owner
    }
  end

  def authorize(resource_types)
    if doorkeeper_token
      types = stringify_types(resource_types)
      unless resource_types.include?(doorkeeper_token.resource_owner_type)
        render json: { errors: "You need to login as a #{types} to access this endpoint" }, status: :forbidden
      end
    else
      render json: { errors: 'You need to login to access this endpoint' }, status: :unauthorized
    end
  end

  def true?(str)
    ActiveModel::Type::Boolean.new.cast str.to_s
  end

  def stringify_types(resource_types)
    if resource_types.is_a? Array
      resource_types.join(' or ')
    else
      resource_types
    end
  end

  def pagination_params
    params.permit(:per, :page)
  end

  def per_page
    pagination_params[:per] || 20
  end

  def page
    pagination_params[:page] || 1
  end

  def update_user_activity
    return if current_resource_owner.blank?

    current_resource_owner.last_activity! if current_resource_owner.instance_of?(PersonalUser)
  end
end
