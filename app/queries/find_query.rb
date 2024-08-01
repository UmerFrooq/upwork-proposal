class FindQuery
  attr_accessor :klass_relation, :search_term, :filter, :associated_models

  def initialize(klass_relation, params = {})
    @klass_relation = klass_relation
    @search_term ||= params[:query]
    @filter ||= params.fetch(:filter, {}).permit(klass_relation.filter_fields).to_h
    @associated_models = klass_relation.associated_models_search.presence
  end

  def call
    relation = build_relation
    relation = relation.where(filter_statement) if filter.present?
    relation = relation.where(build_statement) if search_term.present? || associated_models.present?

    relation
  end

  private

  def build_relation
    return klass_relation if associated_models.blank?

    klass_relation.left_outer_joins(associated_models).distinct
  end

  def filter_statement
    @filter_statement ||=
      filter.collect do |key, value|
        value = value.to_s.split(',').collect(&:strip)
        klass_relation.arel_table[key.to_sym].in(value)
      end

    reduce_to_and(@filter_statement)
  end

  def model_search(model)
    search_fields = model.search_fields
    uuid_search = search_fields.delete(:uuid)
    id_search = search_fields.delete(:id)
    date_search = search_fields.delete(:start_date)
    time_search = search_fields.delete(:start_time)

    search_array = search_fields.collect { |field| model.arel_table[field].matches("%#{search_term}%") }
    search_array << model.arel_table[:uuid].eq(search_term) if uuid_search.present?
    search_array << model.arel_table[:id].eq(search_term) if id_search.present?
    search_array << model.arel_table[:start_date].eq(search_term) if date_search.present?
    search_array << model.arel_table[:start_time].eq(search_term) if time_search.present?

    search_array.reduce(:or)
  end

  def search_associated_models
    @associated_query_statement ||=
      associated_models.collect do |associated_model|
        associated_model = associated_klass(associated_model.to_s).classify.constantize
        model_search(associated_model)
      end
    @associated_query_statement.reduce(:or)
  end

  def associated_klass(association)
    {
      'assigned_worker' => 'vendor_user'
    }[association] || association
  end

  def reduce_to_and(query)
    query.reduce { |statement, condition| statement.and(condition) }
  end

  def build_statement
    return if search_term.blank?
    return if associated_models.blank? && klass_relation.search_fields.blank?

    result = []
    result << query_statement if klass_relation.search_fields.present?
    result << search_associated_models if associated_models.present?

    result.reduce(:or)
  end

  def query_statement
    fields = klass_relation.search_fields
    return unless fields

    model_search(klass_relation)
  end
end
